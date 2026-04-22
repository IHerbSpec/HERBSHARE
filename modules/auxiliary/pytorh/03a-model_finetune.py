#!/usr/bin/env python3


# %% Libraries

import sys
import os
import json
import numpy as np
import polars as pl
import torch
import pywt
from torch.utils.data import DataLoader
from torch.cuda.amp import GradScaler
from torch.optim.lr_scheduler import StepLR
import matplotlib.pyplot as plt
from IPython.display import clear_output

# %% Configuration

# Paths
ROOT_FOLDER = os.getenv('DELTAS_DATA_PATH', '/media/guzman/Work/DELTAS/data')
MODEL_DIR = os.path.join(ROOT_FOLDER, '04-finetune_model')

# Inputs
REFLECTANCE_PATH = os.path.join(ROOT_FOLDER, '02-dataset_training-testing/reflectance_training.csv')
TRAIT_PATH = os.path.join(ROOT_FOLDER, '02-dataset_training-testing/traits_training.csv')

# Pretrained model
PRETRAINED_MODEL_PATH = os.path.join(ROOT_FOLDER, '03-pretrain_model', 'pretrain_regression_model.pth')
PRETRAIN_TRAITS = ['n', 'Cab', 'Car', 'Cw', 'Cm', 'Canth', 'Cbrown']

# Outputs
MODEL_EXPORT_PATH = os.path.join(MODEL_DIR, 'finetune_regression_model.pth')
LOSS_EXPORT_PATH = os.path.join(MODEL_DIR, 'finetune_model_loss.csv')
TRAIT_STATS_PATH = os.path.join(MODEL_DIR, 'trait_stats_out.json')

# Data features
TARGET_TRAITS = ["LMA", "EWT", "LDMC", "Car", "Chla", "Chlb", "Chla+b", 
                 "Hemicellulose", "Cellulose", "Lignin", "N", "C"]
                 
NORMALIZE = True 
WAVELET = 'gaus2'
band_spacing = 1
feature_target = 1.3 ** np.arange(1, 25)
frequencies = band_spacing / feature_target
SCALES = pywt.frequency2scale(WAVELET, frequencies)

# Model features
BATCH_SIZE = 300
NUM_EPOCHS = 300
WARMUP_EPOCHS = 5
LEARNING_RATE = 1e-3
WEIGHT_DECAY = 1e-7
NUM_WORKERS = 25
PATIENCE = 10
SCHEDULER_STEP_SIZE = 3
SCHEDULER_GAMMA = 0.75

# Testing code
N_SAMPLES = None
RANDOM_SEED = 20191107

# %% Source code

UTILS_PATH = os.getenv('DELTAS_UTILS_PATH', '/media/guzman/antonio/Github/TEST/DELTAS/utils')
sys.path.append(UTILS_PATH)
from boxcox_utils import _safe_boxcox_fit, _apply_boxcox
from dataset_definition import load_reflectance, trait_scalogram_dataset
from model_architecture import train, validate, freeze_backbone_model, make_optimizer

# %% Compute normalization factor for traits

# Read traits
schema = pl.read_csv(TRAIT_PATH, n_rows=1).schema
cols = list(schema.keys())

traits = (
    pl.read_csv(TRAIT_PATH, has_header = True)
    .with_columns([
        pl.col(cols[0]).cast(str),
        *[pl.col(c).cast(pl.Float64) for c in cols[1:]]
    ])
)

# Fit Box-Cox per trait
boxcox_params = {}
for col in TARGET_TRAITS:
    if col not in traits.columns:
        continue
    x = traits.select(pl.col(col)).to_numpy().reshape(-1)
    x = x[np.isfinite(x)]  # drop NaN/inf

    lam, shift, used = _safe_boxcox_fit(x)

    # Compute mean and std of transformed values for standardization
    if x.size > 0:
        xt = np.array([_apply_boxcox(v, lam, shift) for v in x])
        trans_mean = float(np.nanmean(xt))
        trans_std = float(np.nanstd(xt))

        # Avoid division by zero
        if trans_std < 1e-8:
            trans_std = 1.0
    else:
        trans_mean, trans_std = 0.0, 1.0

    boxcox_params[col] = {
        "lambda": lam,
        "shift": shift,
        "trans_mean": trans_mean,
        "trans_std": trans_std,
        "used_boxcox": bool(used),
    }

# Store raw min/max
TRAIT_STATS = {
    col: {
        "raw_min": float(traits.select(pl.col(col).min()).item()) if col in traits.columns else None,
        "raw_max": float(traits.select(pl.col(col).max()).item()) if col in traits.columns else None,
        **boxcox_params.get(col, {})
    }
    for col in TARGET_TRAITS
}

os.makedirs(MODEL_DIR, exist_ok=True)
with open(os.path.join(MODEL_DIR, 'finetune_trait_stats.json'), "w") as f:
    json.dump(TRAIT_STATS, f, indent=4)
print("Saved Box-Cox + standardization stats to finetune_trait_stats.json")

# %% Test GPU installation and set seed

if torch.cuda.is_available():
    torch.cuda.manual_seed_all(20191107)
    print("✅ GPU available")
else:
    print("⛔ GPU is not available")

# %% Transfer learning model

def transfer_learning():
    
    # Device
    torch.cuda.empty_cache()
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # Load reflectance
    refl_df, refl_lookup, wavelengths = load_reflectance(REFLECTANCE_PATH, 
                                                         id_col = "rowID")

    # Use the traits dataFrame created earlier
    ids_common = traits.select("rowID").join(refl_df.select("rowID"), 
                                             on = "rowID", 
                                             how = "inner")
    
    traits_pl = traits.join(ids_common, 
                            on = "rowID", 
                            how = "inner")

    # Subset
    if N_SAMPLES is not None and traits_pl.height > N_SAMPLES:
        traits_pl = traits_pl.sample(n = N_SAMPLES,
                                     with_replacement = False,
                                     seed = RANDOM_SEED)
        print(f"⚡ Subsampled to {traits_pl.height} matched samples")

    else:
        print(f"Using all {traits_pl.height} matched samples")

    # Create training and validation split
    train_df = traits_pl.sample(fraction = 0.75, shuffle = True, seed = 37)
    train_ids = set(train_df.select("rowID").to_series().to_list())
    val_df = traits_pl.filter(~pl.col("rowID").is_in(train_ids))

    print(f"📊 Train samples: {train_df.height}, Validation samples: {val_df.height}")

    # Datasets
    train_dataset = trait_scalogram_dataset(train_df,
                                            refl_lookup,
                                            TARGET_TRAITS,
                                            TRAIT_STATS,
                                            wavelet = WAVELET,
                                            scales = SCALES,
                                            normalize = NORMALIZE)

    val_dataset = trait_scalogram_dataset(val_df,
                                          refl_lookup,
                                          TARGET_TRAITS,
                                          TRAIT_STATS,
                                          wavelet = WAVELET,
                                          scales = SCALES,
                                          normalize = NORMALIZE)

    # Data loaders
    train_loader = DataLoader(train_dataset,
                              batch_size = BATCH_SIZE,
                              shuffle = True,
                              num_workers = NUM_WORKERS,
                              pin_memory = True)

    val_loader = DataLoader(val_dataset,
                            batch_size = BATCH_SIZE,
                            shuffle = False,
                            num_workers = NUM_WORKERS,
                            pin_memory = True)
        
    # Warm-up (frozen backbone)    
    best_rmse = float('inf')
    counter = 0
    train_losses, val_losses = [], []
    epochs_done = 0
     
    if WARMUP_EPOCHS > 0:
        
        print(f"🔒 Warm-up for {WARMUP_EPOCHS} epoch(s) (frozen backbone)")
        
        # Model
        model = freeze_backbone_model(new_out_cols = TARGET_TRAITS,
                                      old_ckpt_path = PRETRAINED_MODEL_PATH,
                                      old_out_cols = PRETRAIN_TRAITS,
                                      freeze_backbone = True,
                                      pretrained = False).to(device)

        # Optimizer
        optimizer = make_optimizer(model, 
                                   base_lr = LEARNING_RATE, 
                                   weight_decay = WEIGHT_DECAY)
        
        # Scheduler
        scheduler = StepLR(optimizer, 
                           step_size = SCHEDULER_STEP_SIZE, 
                           gamma = SCHEDULER_GAMMA)
        
        scaler = GradScaler(enabled=(device.type == 'cuda'))

        for epoch in range(WARMUP_EPOCHS):

            train_loss = train(model, train_loader, optimizer, device, scaler)
            val_loss = validate(model, val_loader, device)
            scheduler.step()

            train_losses.append(train_loss)
            val_losses.append(val_loss)
            epochs_done += 1

            try:
                clear_output(wait=True)
                plt.figure(figsize = (7, 5))
                plt.plot(train_losses, label = 'Train')
                plt.plot(val_losses, label = 'Val')
                plt.title("Loss")
                plt.xlabel("Epoch")
                plt.ylabel("RMSE")
                plt.legend(); plt.grid(True); plt.tight_layout(); plt.show()
                plt.close()
            except Exception:
                pass

            print(f"[Warm-up] Epoch {epoch+1}/{WARMUP_EPOCHS} — Train RMSE: {train_loss:.4f}, Val RMSE: {val_loss:.4f}")

            if val_loss < best_rmse:
                best_rmse = val_loss
                torch.save(model.state_dict(), MODEL_EXPORT_PATH)
                counter = 0
                print("✅ Model improved and saved (warm-up)!")
            else:
                counter += 1
                if counter >= PATIENCE:
                    print("⛔ Early stopping (warm-up)")
                    break

    # Fine-tuning
    remaining_epochs = max(0, NUM_EPOCHS - epochs_done)    
    
    if remaining_epochs > 0:
        
        print(f"🧠 Fine-tuning for {remaining_epochs} epoch(s) (unfrozen backbone)")

        # Model
        if WARMUP_EPOCHS == 0:
            model = freeze_backbone_model(new_out_cols = TARGET_TRAITS,
                                          old_ckpt_path = PRETRAINED_MODEL_PATH,
                                          old_out_cols = PRETRAIN_TRAITS,
                                          freeze_backbone = False,
                                          pretrained = False).to(device)
        else:
            # Unfreeze all parameters (backbone and head)
            for name, param in model.named_parameters():
                param.requires_grad = True
        
        # Optimizer
        optimizer = make_optimizer(model, 
                                   base_lr = LEARNING_RATE, 
                                   weight_decay = WEIGHT_DECAY)
        
        # Scheduler
        scheduler = StepLR(optimizer, 
                           step_size = SCHEDULER_STEP_SIZE, 
                           gamma = SCHEDULER_GAMMA)
        
        scaler = GradScaler(enabled=(device.type == 'cuda'))

        for epoch in range(remaining_epochs):
            train_loss = train(model, train_loader, optimizer, device, scaler)
            val_loss = validate(model, val_loader, device)
            scheduler.step()

            train_losses.append(train_loss)
            val_losses.append(val_loss)

            try:
                clear_output(wait=True)
                plt.figure(figsize=(7, 5))
                plt.plot(train_losses, label='Train')
                plt.plot(val_losses, label='Val')
                plt.title("Loss")
                plt.xlabel("Epoch")
                plt.ylabel("RMSE")
                plt.legend(); plt.grid(True); plt.tight_layout(); plt.show()
                plt.close()
            except Exception:
                pass

            epoch_idx = epochs_done + epoch + 1
            print(f"[Finetune] Epoch {epoch_idx}/{NUM_EPOCHS} — Train RMSE: {train_loss:.4f}, Val RMSE: {val_loss:.4f}")

            if val_loss < best_rmse:
                best_rmse = val_loss
                torch.save(model.state_dict(), MODEL_EXPORT_PATH)
                counter = 0
                print("✅ Model improved and saved!")
            else:
                counter += 1
                if counter >= PATIENCE:
                    print("⛔ Early stopping")
                    break

    # Save loss history
    loss_df = pl.DataFrame({
        "epoch": list(range(1, len(train_losses) + 1)),
        "train_loss": train_losses,
        "val_loss": val_losses,
    })
    loss_df.write_csv(LOSS_EXPORT_PATH)
    torch.cuda.empty_cache()

# %% Main
if __name__ == "__main__":
    transfer_learning()
