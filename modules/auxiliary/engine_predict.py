#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Engine prediction script for HERBSPHERE
Simplified wrapper for trait prediction from spectral data
"""

import sys
import os
import json
import argparse
import numpy as np
import polars as pl
import torch
import torch.nn as nn
import pywt
from torch.utils.data import DataLoader
from torch.cuda.amp import autocast
from pathlib import Path

# Get the script directory
SCRIPT_DIR = Path(__file__).parent
PYTORCH_DIR = SCRIPT_DIR / "pytorh"

# Add to path
sys.path.insert(0, str(PYTORCH_DIR))

# Import modules
from dataset_definition import load_reflectance, scalogram_traits_predict, denormalize_predictions
from model_architecture import model_architecture, mc_dropout

# Default configuration
MODEL_PATH = PYTORCH_DIR / "finetune_regression_model.pth"
STATS_PATH = PYTORCH_DIR / "finetune_trait_stats.json"

# Wavelet configuration
WAVELET = 'gaus2'
band_spacing = 1
feature_target = 1.5 ** np.arange(1, 15)
frequencies = band_spacing / feature_target
SCALES = pywt.frequency2scale(WAVELET, frequencies)

# Batch configuration
BATCH_SIZE = 62
NUM_WORKERS = 4

# All available traits
ALL_TRAITS = ["LMA", "EWT", "LDMC", "Car", "Chla", "Chlb", "Chla+b",
              "Hemicellulose", "Cellulose", "Lignin", "N", "C"]


def deterministic_predict(model, loader, device):
    """Run deterministic prediction"""
    model.eval()
    preds = []
    ids_all = []
    use_amp = device.type == "cuda"

    for ids, x, coi_mask in loader:
        x = x.to(device, non_blocking=True)
        coi_mask = coi_mask.to(device, non_blocking=True)

        with torch.no_grad():
            with autocast(enabled=use_amp):
                out = model(x, coi_mask=coi_mask)

        preds.append(out.cpu())
        ids_all.extend(ids)

    preds = torch.cat(preds, dim=0)
    return ids_all, preds.numpy()


def uncertainty_predict(model, loader, device, num_passes=100, dropout_p=None):
    """Run MC-Dropout uncertainty prediction"""
    model.eval()
    mc_dropout(model, dropout_p=dropout_p)

    preds_stack = []

    for _ in range(num_passes):
        batch_preds = []
        for _, x, coi_mask in loader:
            x = x.to(device, non_blocking=True)
            coi_mask = coi_mask.to(device, non_blocking=True)

            with torch.no_grad():
                with autocast(enabled=device.type == "cuda"):
                    out = model(x, coi_mask=coi_mask)

            batch_preds.append(out.cpu())

        pass_preds = torch.cat(batch_preds, dim=0)
        preds_stack.append(pass_preds.unsqueeze(0))

    preds_stack = torch.cat(preds_stack, dim=0).numpy()
    q0025 = np.percentile(preds_stack, 2.5, axis=0)
    q0975 = np.percentile(preds_stack, 97.5, axis=0)
    return q0025, q0975


def predict_traits(input_path, output_path, target_traits=None, use_uncertainty=False):
    """Main prediction function"""

    # Use all traits if not specified
    if target_traits is None:
        target_traits = ALL_TRAITS

    # Validate traits
    invalid_traits = [t for t in target_traits if t not in ALL_TRAITS]
    if invalid_traits:
        raise ValueError(f"Invalid traits: {invalid_traits}")

    print(f"Predicting {len(target_traits)} traits: {', '.join(target_traits)}")

    # Check device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")

    # Load reflectance
    print(f"Loading reflectance from: {input_path}")
    refl_df, refl_lookup, _ = load_reflectance(input_path, id_col="rowID")
    print(f"Loaded {len(refl_lookup)} samples")

    # Create scalograms dataset
    print("Computing scalograms...")
    ds = scalogram_traits_predict(
        df=refl_df.select(["rowID"]),
        reflectance=refl_lookup,
        wavelet=WAVELET,
        scales=SCALES
    )

    # Create data loader
    loader = DataLoader(
        ds,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=NUM_WORKERS,
        pin_memory=True
    )

    # Load trait stats
    with open(STATS_PATH, "r") as f:
        trait_stats = json.load(f)

    # Load model
    print("Loading model...")
    model = model_architecture(out_dim=len(ALL_TRAITS)).to(device)
    state = torch.load(MODEL_PATH, map_location=device)
    model.load_state_dict(state)
    model.eval()

    # Get predictions
    print("Running predictions...")
    ids, predict_deterministic = deterministic_predict(model, loader, device)

    # Get uncertainty if requested
    if use_uncertainty:
        print("Computing uncertainty estimates...")
        q0025_norm, q0975_norm = uncertainty_predict(
            model=model,
            loader=loader,
            device=device,
            num_passes=100,
            dropout_p=None
        )
    else:
        q0025_norm, q0975_norm = None, None

    # Denormalize predictions
    print("Denormalizing predictions...")
    denorm_deterministic = denormalize_predictions(
        predict_deterministic,
        trait_stats,
        normalize=True,
        target_traits=ALL_TRAITS
    )

    if use_uncertainty:
        denorm_q0025 = denormalize_predictions(
            q0025_norm,
            trait_stats,
            normalize=True,
            target_traits=ALL_TRAITS
        )
        denorm_q0975 = denormalize_predictions(
            q0975_norm,
            trait_stats,
            normalize=True,
            target_traits=ALL_TRAITS
        )

    # Build output DataFrame (only selected traits)
    print("Building output...")
    pred_df = pl.DataFrame({"rowID": ids})

    # Get indices for selected traits
    trait_indices = [i for i, t in enumerate(ALL_TRAITS) if t in target_traits]

    for idx in trait_indices:
        col = ALL_TRAITS[idx]
        deter = denorm_deterministic[col]
        pred_df = pred_df.with_columns(pl.Series(col, deter))

        if use_uncertainty:
            lo = denorm_q0025[col]
            hi = denorm_q0975[col]

            pred_df = pred_df.with_columns([
                pl.Series(f"{col}_q0025", lo),
                pl.Series(f"{col}_q0975", hi),
                pl.Series(f"{col}_uncertainty", np.asarray(hi) - np.asarray(lo)),
            ])

    # Save predictions
    print(f"Saving predictions to: {output_path}")
    pred_df.write_csv(output_path)
    print(f"✅ Predictions saved successfully!")

    # Clean up
    torch.cuda.empty_cache()


def main():
    """Command line interface"""
    parser = argparse.ArgumentParser(description="Predict leaf traits from spectral data")

    parser.add_argument("--input", required=True, help="Input CSV with reflectance data")
    parser.add_argument("--output", required=True, help="Output CSV for predictions")
    parser.add_argument("--traits", default=None, help="Comma-separated list of traits to predict")
    parser.add_argument("--uncertainty", action="store_true", help="Compute MC-Dropout uncertainty")

    args = parser.parse_args()

    # Parse traits
    if args.traits:
        target_traits = [t.strip() for t in args.traits.split(",")]
    else:
        target_traits = ALL_TRAITS

    # Run prediction
    try:
        predict_traits(
            input_path=args.input,
            output_path=args.output,
            target_traits=target_traits,
            use_uncertainty=args.uncertainty
        )
        sys.exit(0)

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
