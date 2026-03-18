#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# %% Libraries

import sys
import polars as pl
import numpy as np
import pywt
import torch
from torch.utils.data import Dataset

sys.path.append('/media/guzman/antonio/Github/TEST/DELTAS/utils')
from boxcox_utils import _has_boxcox_params, _inv_boxcox_vec, _apply_boxcox

# %% Dataset definition

EPS = 1e-8

# Load reflectance
def load_reflectance(csv_path: str, id_col: str = "rowID"):

    refl_df = pl.read_csv(csv_path).with_columns(pl.col(id_col).cast(pl.Utf8))
    all_cols = refl_df.columns
    wave_cols = [
        c for c in all_cols[1:]
        if c.replace('.', '', 1).isdigit() and 450 <= float(c) <= 2399
    ]
    refl_df = refl_df.select([id_col] + wave_cols)
    ids = refl_df[:, 0].to_numpy().flatten()
    spectra = refl_df[:, 1:].to_numpy().astype(np.float32)
    spectra = np.nan_to_num(spectra, nan = 0.0, posinf = 0.0, neginf = 0.0)
    refl_lookup = {ids[i]: spectra[i] for i in range(len(ids))}
    return refl_df, refl_lookup, wave_cols

# Make a scalogram (visualization only)
def scalogram(y: np.ndarray, scales: np.ndarray, wavelet: str) -> torch.Tensor:
    coeffs, _ = pywt.cwt(y.squeeze(), scales, wavelet)
    coeffs = coeffs.astype(np.float32, copy=False)
    img = coeffs[np.newaxis, :, :]
    ten = torch.from_numpy(img)[None, ...]
    return ten

# Cone of influence mask
def mask_cwt(signal_len: int,
            scales: np.ndarray,
            wavelet: str) -> np.ndarray:
    
    cw = pywt.ContinuousWavelet(wavelet)
    psi, x = cw.wavefun(length=1024)
    base_half_width = float(np.max(np.abs(x)))

    mask = np.ones((len(scales), signal_len), dtype=bool)

    for i, s in enumerate(scales):
        half_width = base_half_width * float(s)
        margin = int(np.ceil(half_width))

        mask[i, :margin] = False
        mask[i, signal_len - margin:] = False

    return mask

# CWT and traits
class trait_scalogram_dataset(Dataset):

    def __init__(
        self,
        df: pl.DataFrame,
        reflectance: dict[str, np.ndarray],
        target_traits: list[str],
        trait_stats: dict,
        wavelet: str = 'gaus2',
        scales: np.ndarray = None,
        normalize: bool = True
    ):
        self.df = df
        self.reflectance = reflectance
        self.target_traits = target_traits
        self.trait_stats = trait_stats
        self.col_idx = {col: i for i, col in enumerate(df.columns)}
        self.wavelet = wavelet
        self.scales = np.array(scales if scales is not None else np.arange(1, 25), dtype=np.float32)
        self.normalize = normalize

        # Validate that every ID has reflectance
        missing = []
        for i in range(self.df.height):
            _id = self.df.row(i)[self.col_idx["rowID"]]
            
            if _id not in self.reflectance:
                missing.append(_id)
                
        if missing:
            raise ValueError(f"{len(missing)} IDs in traits are missing.")

    def __len__(self):
        return self.df.height

    def __getitem__(self, idx):
              
        row = self.df.row(idx)
        sample_id = row[self.col_idx["rowID"]]

        # Get reflectance vector y and compute CWT scalogram
        y = self.reflectance[sample_id].squeeze()
        coeffs, _ = pywt.cwt(y, self.scales, self.wavelet)
        coeffs = coeffs.astype(np.float32, copy = False)
        
        # Apply mask
        cone_of_influence = mask_cwt(signal_len=len(y),
                                     scales=self.scales,
                                     wavelet=self.wavelet)     
        
        # Set coefficients to 0
        coeffs = np.where(cone_of_influence, coeffs, 0.0).astype(np.float32, copy=False)
        
        # Build tensors
        img = coeffs[np.newaxis, :, :] 
        scalogram_tensor = torch.from_numpy(img)
        valid_scalogram = torch.from_numpy(cone_of_influence.astype(np.bool_))
        
        # Normalize traits
        
        values = []
        trait_mask = []
        
        for col in self.target_traits:
            val = row[self.col_idx[col]]
            
            # If missing / non-finite trait
            if val is None or not np.isfinite(val):
                values.append(-1.0)
                trait_mask.append(False)
                continue

            if self.normalize:
                st = self.trait_stats.get(col, {})
                if not _has_boxcox_params(st):
                    values.append(-1.0)
                    trait_mask.append(False)
                    continue

                # Step 1: Box-Cox transformation
                lam = float(st["lambda"])
                shift = float(st["shift"])
                v_bc = _apply_boxcox(float(val), lam, shift)

                # Step 2: Standardization (mean=0, std=1)
                trans_mean = float(st["trans_mean"])
                trans_std = float(st["trans_std"])
                v_standardized = (v_bc - trans_mean) / trans_std

                # Step 3: Soft compression using tanh
                # Maps ±∞ to [-1, 1] smoothly, preserving extreme values
                v_compressed = np.tanh(v_standardized / 3.0)

                # Step 4: Scale to [0, 100]
                v_scaled = (v_compressed + 1.0) / 2.0 * 100.0
                v_scaled = float(max(v_scaled, 1e-5))

                values.append(v_scaled)
                trait_mask.append(True)
                
            else:
                values.append(float(val))
                trait_mask.append(True)
        
        values_tensor = torch.tensor(values, dtype = torch.float32)
        trait_mask_tensor = torch.tensor(trait_mask, dtype = torch.bool)
        
        return scalogram_tensor, values_tensor, trait_mask_tensor, valid_scalogram

# %% Predict from scalograms

class scalogram_traits_predict(Dataset):
    def __init__(self, df: pl.DataFrame,
                 reflectance: dict[str, np.ndarray],
                 wavelet: str = 'gaus2', 
                 scales: np.ndarray | None = None):
        
        self.df = df
        self.reflectance = reflectance
        self.col_idx = {col: i for i, col in enumerate(df.columns)}
        self.wavelet = wavelet
        self.scales = np.array(scales if scales is not None else np.arange(1, 25), dtype=np.float32)

        missing = []
        for i in range(self.df.height):
            _id = self.df.row(i)[self.col_idx["rowID"]]
            if _id not in self.reflectance:
                missing.append(_id)
        if missing:
            raise ValueError(f"{len(missing)} IDs are missing reflectance")

    def __len__(self):
        return self.df.height

    def __getitem__(self, idx):
        
        # Select row
        row = self.df.row(idx)
        sample_id = row[self.col_idx["rowID"]]
        
        # Get reflectance
        y = self.reflectance[sample_id].squeeze()   
        
        # Compute CWT
        coeffs, _ = pywt.cwt(y, self.scales, self.wavelet)
        coeffs = coeffs.astype(np.float32, copy=False)
        
        # Mask cone of influence
        cone_of_influence = mask_cwt(signal_len=len(y),
                                     scales=self.scales,
                                     wavelet=self.wavelet) 
        
        # Apply mask
        coeffs = np.where(cone_of_influence, coeffs, 0.0).astype(np.float32, copy=False)
        
        # Build tensors
        img = coeffs[np.newaxis, :, :]
        scalogram_tensor = torch.from_numpy(img)
        
        valid_scalogram = torch.from_numpy(cone_of_influence.astype(np.bool_))
        
        return sample_id, scalogram_tensor, valid_scalogram

# %% Inference helpers

def denormalize_predictions(pred_np: np.ndarray,
                         trait_stats: dict[str, dict],
                         normalize: bool,
                         target_traits: list[str]) -> dict[str, np.ndarray]:
    
    out: dict[str, np.ndarray] = {}

    if not normalize:
        for j, col in enumerate(target_traits):
            out[col] = pred_np[:, j]
        return out

    if trait_stats is None:
        raise ValueError("trait_stats is required when normalize=True.")

    for j, col in enumerate(target_traits):
        st = trait_stats.get(col, {})
        y = pred_np[:, j].astype(np.float64)

        if _has_boxcox_params(st):

            # Reverse Step 4: Map [0, 100] back to [-1, 1]
            y_clipped = np.clip(y, 0.0, 100.0)
            y_compressed = (y_clipped / 100.0) * 2.0 - 1.0

            # Reverse Step 3: Apply arctanh (inverse of tanh)
            # Clip to avoid arctanh domain issues (must be in (-1, 1))
            y_compressed = np.clip(y_compressed, -0.999999, 0.999999)
            y_standardized = np.arctanh(y_compressed) * 3.0

            # Reverse Step 2: Unstandardize (multiply by std, add mean)
            trans_mean = float(st["trans_mean"])
            trans_std = float(st["trans_std"])
            y_trans = y_standardized * trans_std + trans_mean

            # Reverse Step 1: Invert Box-Cox, then remove shift
            lam = float(st["lambda"])
            shift = float(st["shift"])
            xp = _inv_boxcox_vec(y_trans, lam)  # xp = x + shift
            x_orig = xp - shift
            out[col] = x_orig.astype(np.float64)

        elif ("min" in st) and ("max" in st):
            # Fallback if you ever store raw min/max instead
            vmin = float(st["min"])
            vmax = float(st["max"])
            out[col] = ((np.clip(y, 0.0, 100.0) - 0.00001) / (100.0 - 0.00001)) * (vmax - vmin) + vmin
        else:
            # No stats: pass through
            out[col] = y

    return out