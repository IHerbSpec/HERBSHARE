#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# %% Libraries

import sys
import os
import json
import numpy as np
import polars as pl
import torch
import torch.nn as nn
import pywt
from torch.utils.data import DataLoader
from torch.cuda.amp import autocast
from tqdm import tqdm

# %% Configuration

# Root path (use environment variable if set, otherwise use default)
ROOT_FOLDER = os.getenv('DELTAS_DATA_PATH', '/media/guzman/Work/DELTAS/data')
MODEL_DIR = os.path.join(ROOT_FOLDER, '04-finetune_model')

# Reflectance
#REFLECTANCE_PATH = os.path.join(ROOT_FOLDER, '02-dataset_training-testing/reflectance_training.csv')
#PREDICTIONS_EXPORT_PATH = os.path.join(MODEL_DIR , 'predictions_training.csv')

REFLECTANCE_PATH = os.path.join(ROOT_FOLDER, '02-dataset_training-testing/reflectance_testing.csv')
PREDICTIONS_EXPORT_PATH = os.path.join(MODEL_DIR, 'predictions_testing.csv')

# Models
MODEL_EXPORT_PATH = os.path.join(MODEL_DIR, 'finetune_regression_model.pth')
TRAIT_STATS_PATH = os.path.join(MODEL_DIR, 'finetune_trait_stats.json')

# Target traits to predict
TARGET_TRAITS = ["LMA", "EWT", "LDMC", "Car", "Chla", "Chlb", "Chla+b", 
                 "Hemicellulose", "Cellulose", "Lignin", "N", "C"]

NORMALIZE = True

# Model features
WAVELET = 'gaus2'
band_spacing = 1
feature_target = 1.3 ** np.arange(1, 25)
frequencies = band_spacing / feature_target
SCALES = pywt.frequency2scale(WAVELET, frequencies)

BATCH_SIZE = 800
NUM_WORKERS = 25

# Model and data features
USE_UNCERTAINTY = False
MC_PASSES = 100
DROPOUT_OVERRIDE = None

# %% Source code

UTILS_PATH = os.getenv('DELTAS_UTILS_PATH', '/media/guzman/antonio/Github/TEST/DELTAS/utils')
sys.path.append(UTILS_PATH)
from dataset_definition import load_reflectance, scalogram_traits_predict, denormalize_predictions
from model_architecture import model_architecture, mc_dropout

# %% Deterministic model predict

def deterministic(model, loader, device):
    model.eval()
    preds = []
    ids_all = []
    use_amp = device.type == "cuda"

    for ids, x, coi_mask in tqdm(loader, desc="Estimating traits", unit="batch"):
        x = x.to(device, non_blocking=True)
        coi_mask = coi_mask.to(device, non_blocking=True)

        with torch.no_grad():
            with autocast(enabled=use_amp):
                out = model(x, coi_mask=coi_mask)

        preds.append(out.cpu())
        ids_all.extend(ids)

    preds = torch.cat(preds, dim=0)
    return ids_all, preds.numpy()

# %% Predict uncertainty (MC-Dropout)
def uncertainty(model: nn.Module,
               loader, 
               device: torch.device,
               num_passes: int, 
               dropout_p: float | None = None):

    model.eval()
    mc_dropout(model, dropout_p=dropout_p)

    preds_stack = []
    total_steps = num_passes * len(loader)
    pbar = tqdm(total=total_steps,
                desc=f"Estimating uncertainty: {num_passes} passes",
                unit="step")

    for _ in range(num_passes):
        batch_preds = []
        for _, x, coi_mask in loader:
            x = x.to(device, non_blocking=True)
            coi_mask = coi_mask.to(device, non_blocking=True)

            out = model(x, coi_mask=coi_mask)
            batch_preds.append(out.detach().cpu())
            pbar.update(1)

        pass_preds = torch.cat(batch_preds, dim=0)
        preds_stack.append(pass_preds.unsqueeze(0))

    pbar.close()

    preds_stack = torch.cat(preds_stack, dim=0).numpy()
    q0025 = np.percentile(preds_stack, 2.5, axis=0)
    q0975 = np.percentile(preds_stack, 97.5, axis=0)
    return q0025, q0975

# %% Predict traits
def predict_traits():
    
    # Check GPUs
    torch.cuda.empty_cache()
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    # Load reflectance
    refl_df, refl_lookup, _ = load_reflectance(REFLECTANCE_PATH, id_col = "rowID")

    # Create scalograms
    ds = scalogram_traits_predict(df = refl_df.select(["rowID"]),
                                  reflectance = refl_lookup,
                                  wavelet = WAVELET,
                                  scales = SCALES)
    
    # Load scalograms for Pytorh
    loader = DataLoader(ds, 
                        batch_size = BATCH_SIZE, 
                        shuffle = False,
                        num_workers = NUM_WORKERS, 
                        pin_memory = True)
  
    # Load stats only if we need to denormalize
    trait_stats = None
    if NORMALIZE:
        with open(TRAIT_STATS_PATH, "r") as f:
            trait_stats = json.load(f)
            
    # Load model
    model = model_architecture(out_dim = len(TARGET_TRAITS), pretrained = False).to(device)
    state = torch.load(MODEL_EXPORT_PATH, map_location = device)
    model.load_state_dict(state)
    model.eval()
    
    # Get deterministic prediction
    ids, predict_deterministic = deterministic(model, loader, device)
    
    # Get uncertainty (MC-Dropout)
    if USE_UNCERTAINTY:
        q0025_norm, q0975_norm = uncertainty(model = model,
                                             loader = loader,
                                             device = device,
                                             num_passes = MC_PASSES,
                                             dropout_p = DROPOUT_OVERRIDE)
    else:
        q0025_norm, q0975_norm = None, None
    
    # Denormalize
    denorm_deterministic = denormalize_predictions(predict_deterministic,
                                                   trait_stats,
                                                   normalize = NORMALIZE,
                                                   target_traits = TARGET_TRAITS)
    
    if USE_UNCERTAINTY:
        
        denorm_q0025 = denormalize_predictions(q0025_norm,
                                               trait_stats,
                                               normalize = NORMALIZE,
                                               target_traits = TARGET_TRAITS)
        
        denorm_q0975 = denormalize_predictions(q0975_norm,
                                               trait_stats,
                                               normalize = NORMALIZE,
                                               target_traits = TARGET_TRAITS)
    
    # Build output DataFrame
    pred_df = pl.DataFrame({"rowID": ids})
        
    # Add columns per trait
    for j, col in enumerate(TARGET_TRAITS):
        
        deter = denorm_deterministic[col]
        pred_df = pred_df.with_columns(pl.Series(col, deter))
        
        if USE_UNCERTAINTY:
                        
            lo = denorm_q0025[col]
            hi = denorm_q0975[col]
            
            pred_df = pred_df.with_columns([
                pl.Series(f"{col}_q0025", lo),
                pl.Series(f"{col}_q0975", hi),
                pl.Series(f"{col}_uncertainty", np.asarray(hi) - np.asarray(lo)),
            ])

    # Save
    os.makedirs(MODEL_DIR, exist_ok = True)
    pred_df.write_csv(PREDICTIONS_EXPORT_PATH)
    torch.cuda.empty_cache()
    print(f"✅ Saved predictions to: {PREDICTIONS_EXPORT_PATH}")
    
# %% Main
if __name__ == "__main__":
    predict_traits()
    torch.cuda.empty_cache()
