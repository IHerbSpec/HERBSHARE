#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
DELTAS - CWT scalogram regression with Patch-wise Transformer (Option A)

This script is a *drop-in replacement* for your current `model_architecture.py` style file.
It keeps the same public API you already use:

- class model_architecture(nn.Module):
    - __init__(out_dim, dropout_p, head_hidden=...)  # head_hidden kept for compatibility
    - forward(x, coi_mask=None) -> predictions

- mc_dropout(model, dropout_p=None)
- rmse_loss(predictions, traits, mask)
- train(model, dataloader, optimizer, device, scaler)
- validate(model, dataloader, device)
- freeze_backbone_model(...)   (adapted: now it copies everything except last linear if out_dim changes)
- make_optimizer(model, base_lr=..., weight_decay=...)

Plus: patch-importance over time-frequency regions (scale×wavelength patches)
- compute_patch_importance(...)
- upscale_patch_importance(...)

IMPORTANT:
- This model expects scalograms shaped (B, 1, H, W).
- H and W must be divisible by PATCH_SIZE=(ph,pw). If not, either pad/crop in your dataset
  or set PATCH_SIZE that divides your scalogram dimensions.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Optional, Tuple, List

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.cuda.amp import autocast


# ============================================================
# Configuration (edit these defaults if you want)
# ============================================================
PATCH_SIZE_DEFAULT: Tuple[int, int] = (2, 5)   # (scale_patch, wavelength_patch)
EMBED_DIM_DEFAULT: int = 256
DEPTH_DEFAULT: int = 8
NUM_HEADS_DEFAULT: int = 8
MLP_RATIO_DEFAULT: float = 4.0
DROPOUT_DEFAULT: float = 0.10


# ============================================================
# Model: Patch-wise Transformer regressor
# ============================================================
class model_architecture(nn.Module):
    """
    Closest conceptual match to the figure (embedding -> transformer encoder -> pooling -> FC output),
    but operating on 2D CWT scalograms via patch tokens.
    """

    def __init__(
        self,
        out_dim: int,
        dropout_p: float = 0.25,
        head_hidden: int | None = 512,        
        patch_size: Tuple[int, int] = PATCH_SIZE_DEFAULT,
        embed_dim: int = EMBED_DIM_DEFAULT,
        depth: int = DEPTH_DEFAULT,
        num_heads: int = NUM_HEADS_DEFAULT,
        mlp_ratio: float = MLP_RATIO_DEFAULT,
    ):
        super().__init__()

        self.out_dim = out_dim
        self.patch_size = patch_size
        self.embed_dim = embed_dim
        self.depth = depth
        self.num_heads = num_heads
        self.mlp_ratio = mlp_ratio
        
        self.patch_embed = nn.Conv2d(
            in_channels=1,
            out_channels=embed_dim,
            kernel_size=patch_size,
            stride=patch_size,
            bias=True,
        )

        # Dropout
        self.dropout = nn.Dropout(p=min(max(float(dropout_p), 0.0), 0.95))

        # Transformer encoder
        enc_layer = nn.TransformerEncoderLayer(
            d_model=embed_dim,
            nhead=num_heads,
            dim_feedforward=int(embed_dim * mlp_ratio),
            dropout=min(max(float(dropout_p), 0.0), 0.95),
            activation="gelu",
            batch_first=True,   # (B, T, C)
            norm_first=True,
        )
        self.encoder = nn.TransformerEncoder(enc_layer, num_layers=depth)

        # Regression head        
        if head_hidden is None:
            self.head = nn.Sequential(
                nn.LayerNorm(embed_dim),
                nn.Dropout(p=min(max(float(dropout_p), 0.0), 0.95)),
                nn.Linear(embed_dim, out_dim),
            )
            nn.init.kaiming_normal_(self.head[-1].weight, nonlinearity="relu")
            nn.init.zeros_(self.head[-1].bias)
        else:
            self.head = nn.Sequential(
                nn.LayerNorm(embed_dim),
                nn.Dropout(p=min(max(float(dropout_p), 0.0), 0.95)),
                nn.Linear(embed_dim, head_hidden),
                nn.GELU(),
                nn.Dropout(p=min(max(float(dropout_p), 0.0), 0.95)),
                nn.Linear(head_hidden, out_dim),
            )
            nn.init.kaiming_normal_(self.head[2].weight, nonlinearity="relu")
            nn.init.zeros_(self.head[2].bias)
            nn.init.kaiming_normal_(self.head[-1].weight, nonlinearity="relu")
            nn.init.zeros_(self.head[-1].bias)

        # Init patch embedding
        nn.init.trunc_normal_(self.patch_embed.weight, std=0.02)
        nn.init.zeros_(self.patch_embed.bias)

        # Internal cache for importance methods
        self._last_tokens: Optional[torch.Tensor] = None

    def _check_divisible(self, H: int, W: int):
        ph, pw = self.patch_size
        if (H % ph) != 0 or (W % pw) != 0:
            raise ValueError(
                f"Input scalogram spatial dims (H={H}, W={W}) must be divisible by patch_size={self.patch_size}. "
                f"Either pad/crop in dataset, or change patch_size."
            )

    def forward(self, x: torch.Tensor, coi_mask: Optional[torch.Tensor] = None) -> torch.Tensor:
        """
        x: (B,1,H,W) scalograms
        coi_mask: optional mask broadcastable to x (B,1,H,W) or (1,1,H,W)
        """
        if x.ndim != 4 or x.shape[1] != 1:
            raise ValueError(f"Expected x as (B,1,H,W), got {tuple(x.shape)}")

        B, _, H, W = x.shape
        self._check_divisible(H, W)

        if coi_mask is not None:
            coi_mask = coi_mask.to(device=x.device, dtype=x.dtype)
            
            if coi_mask.ndim == 2:
                coi_mask = coi_mask.unsqueeze(0).unsqueeze(0)
            elif coi_mask.ndim == 3:
                coi_mask = coi_mask.unsqueeze(1)
            elif coi_mask.ndim == 4:                
                pass
            else:
                raise ValueError(f"Unsupported coi_mask shape {tuple(coi_mask.shape)}")
            x = x * coi_mask

        # Patchify/Embed
        z = self.patch_embed(x)
        B, C, Hp, Wp = z.shape

        # Tokens
        z = z.flatten(2).transpose(1, 2)
        z = self.dropout(z)

        # Transformer encoder
        z = self.encoder(z)

        # Save for attribution if user wants it later
        self._last_tokens = z

        # Pool (adaptive avg pooling analog)
        z = z.mean(dim=1)

        # Regress
        return self.head(z)

    @torch.no_grad()
    def patch_grid(self, H: int, W: int) -> Tuple[int, int]:
        """Return (Hp,Wp) given input H,W."""
        ph, pw = self.patch_size
        return (H // ph, W // pw)


# ============================================================
# MC dropout (unchanged conceptually)
# ============================================================
def mc_dropout(model: nn.Module, dropout_p: float | None = None):
    """
    Enable dropout at inference time (MC dropout). Keeps norm layers in eval.
    """
    for m in model.modules():
        if isinstance(m, (nn.Dropout, nn.Dropout1d, nn.Dropout2d, nn.Dropout3d)):
            m.train()
            if dropout_p is not None:
                m.p = float(dropout_p)
        elif isinstance(m, (nn.BatchNorm1d, nn.BatchNorm2d, nn.BatchNorm3d, nn.SyncBatchNorm, nn.LayerNorm)):
            m.eval()


# ============================================================
# Loss function (your masked RMSE)
# ============================================================
def rmse_loss(predictions: torch.Tensor, traits: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    squared_diff = (predictions - traits) ** 2
    masked_diff = squared_diff * mask
    mse = masked_diff.sum() / mask.sum().clamp(min=1.0)
    return torch.sqrt(mse)


# ============================================================
# Training / validation loops (same signature as your code)
# ============================================================
def train(model: nn.Module, dataloader, optimizer, device, scaler):
    model.train()
    total_loss = 0.0
    use_amp = device.type == "cuda"

    for scalograms, traits, trait_masks, coi_mask in dataloader:       
        scalograms = scalograms.to(device, non_blocking=True)
        traits = traits.to(device, non_blocking=True)
        trait_masks = trait_masks.to(device, non_blocking=True)
        coi_mask = None if coi_mask is None else coi_mask.to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)

        with autocast(enabled=use_amp):
            outputs = model(scalograms, coi_mask=coi_mask)
            loss = rmse_loss(outputs, traits, trait_masks)

        scaler.scale(loss).backward()
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        scaler.step(optimizer)
        scaler.update()

        total_loss += float(loss.item())

    return total_loss / max(1, len(dataloader))


@torch.no_grad()
def validate(model: nn.Module, dataloader, device):
    model.eval()
    total_loss = 0.0
    use_amp = device.type == "cuda"

    for scalograms, traits, trait_masks, coi_mask in dataloader:
        scalograms = scalograms.to(device, non_blocking=True)
        traits = traits.to(device, non_blocking=True)
        trait_masks = trait_masks.to(device, non_blocking=True)
        coi_mask = None if coi_mask is None else coi_mask.to(device, non_blocking=True)

        with autocast(enabled=use_amp):
            outputs = model(scalograms, coi_mask=coi_mask)
            loss = rmse_loss(outputs, traits, trait_masks)

        total_loss += float(loss.item())

    return total_loss / max(1, len(dataloader))


# ============================================================
# Transfer learning / head swapping (adapted to transformer)
# ============================================================
def _last_linear_in_head(head: nn.Sequential) -> nn.Linear:
    last_linear = None
    for m in head.modules():
        if isinstance(m, nn.Linear):
            last_linear = m
    if last_linear is None:
        raise RuntimeError("No Linear layer found in the head.")
    return last_linear


def freeze_backbone_model(
    new_out_cols: List[str],
    old_ckpt_path: str,
    old_out_cols: Optional[List[str]] = None,
    freeze_backbone: bool = False,
    dropout_p: float = 0.2,
    head_hidden: int | None = 512,
    # must match old model hyperparams if you want to load weights cleanly
    patch_size: Tuple[int, int] = PATCH_SIZE_DEFAULT,
    embed_dim: int = EMBED_DIM_DEFAULT,
    depth: int = DEPTH_DEFAULT,
    num_heads: int = NUM_HEADS_DEFAULT,
    mlp_ratio: float = MLP_RATIO_DEFAULT,
) -> nn.Module:
    """
    Loads old checkpoint, builds a new model with new_out_dim, copies all weights.
    If old_out_cols is provided, it will map the final linear layer rows by trait name.
    If freeze_backbone=True, it freezes patch_embed + encoder, leaving only head trainable.
    """

    # 1) Load old model
    old_out_dim = len(old_out_cols) if old_out_cols is not None else 7
    old_model = model_architecture(
        out_dim=old_out_dim,
        dropout_p=dropout_p,
        head_hidden=head_hidden,
        patch_size=patch_size,
        embed_dim=embed_dim,
        depth=depth,
        num_heads=num_heads,
        mlp_ratio=mlp_ratio,
    )
    old_sd = torch.load(old_ckpt_path, map_location="cpu")
    old_model.load_state_dict(old_sd, strict=True)

    # 2) New model
    new_out_dim = len(new_out_cols)
    new_model = model_architecture(
        out_dim=new_out_dim,
        dropout_p=dropout_p,
        head_hidden=head_hidden,
        patch_size=patch_size,
        embed_dim=embed_dim,
        depth=depth,
        num_heads=num_heads,
        mlp_ratio=mlp_ratio,
    )

    nsd = new_model.state_dict()
    osd = old_model.state_dict()

    # 3) Copy everything that exists with same shape, except last linear if out_dim differs
    # Identify last head Linear keys for mapping
    def _find_last_linear_keys(m: model_architecture):
        last_lin = _last_linear_in_head(m.head)
        # find its keys in state_dict
        w_key = None
        b_key = None
        for k in m.state_dict().keys():
            if k.endswith(".weight") and m.state_dict()[k].shape == last_lin.weight.shape:
                # could match multiple, so prefer keys that include "head"
                if "head" in k:
                    w_key = k
            if k.endswith(".bias") and m.state_dict()[k].shape == last_lin.bias.shape:
                if "head" in k:
                    b_key = k
        if w_key is None or b_key is None:
            raise RuntimeError("Could not locate last Linear keys in head for mapping.")
        return w_key, b_key

    old_w_key, old_b_key = _find_last_linear_keys(old_model)
    new_w_key, new_b_key = _find_last_linear_keys(new_model)

    for k, v in osd.items():
        if k in (old_w_key, old_b_key):
            continue
        if k in nsd and nsd[k].shape == v.shape:
            nsd[k] = v

    # 4) Map last linear rows if trait names provided
    if old_out_cols is not None:
        W_old = osd[old_w_key]
        b_old = osd[old_b_key]
        W_new = nsd[new_w_key]
        b_new = nsd[new_b_key]

        name_to_old_idx = {name: i for i, name in enumerate(old_out_cols)}
        for new_i, name in enumerate(new_out_cols):
            if name in name_to_old_idx:
                old_i = name_to_old_idx[name]
                W_new[new_i, :] = W_old[old_i, :]
                b_new[new_i] = b_old[old_i]

        nsd[new_w_key] = W_new
        nsd[new_b_key] = b_new

    new_model.load_state_dict(nsd, strict=False)

    # 5) Optional freeze patch_embed + encoder
    if freeze_backbone:
        for n, p in new_model.named_parameters():
            if n.startswith("patch_embed.") or n.startswith("encoder."):
                p.requires_grad = False

    return new_model


# ============================================================
# Optimizer (keeps your function name/signature)
# ============================================================
def make_optimizer(
    model: nn.Module,
    base_lr: float = 1e-3,
    weight_decay: float = 1e-4
) -> torch.optim.Optimizer:
    """
    For transformer, a simple AdamW is typical.
    Kept signature compatible with your original.
    """
    return torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=base_lr,
        weight_decay=weight_decay
    )


# ============================================================
# Patch-importance over time-frequency regions (scale×wavelength patches)
# ============================================================
@torch.no_grad()
def upscale_patch_importance(
    patch_imp: torch.Tensor,
    input_hw: Tuple[int, int],
    patch_size: Tuple[int, int],
    mode: str = "nearest"
) -> torch.Tensor:
    """
    patch_imp: (Hp, Wp) importance per patch token
    returns: (H, W) upsampled map aligned to input scalogram size
    """
    H, W = input_hw
    ph, pw = patch_size
    Hp, Wp = patch_imp.shape
    if Hp * ph != H or Wp * pw != W:
        raise ValueError("patch_imp shape does not match input_hw given patch_size.")
    x = patch_imp[None, None, :, :]  # (1,1,Hp,Wp)
    x = F.interpolate(x, size=(H, W), mode=mode)
    return x[0, 0]


def compute_patch_importance(
    model: model_architecture,
    dataloader,
    device: torch.device,
    target_index: int = 0,
    num_batches: int = 10,
    use_abs: bool = True,
) -> torch.Tensor:
    """
    Compute patch importance for *one* output dimension (trait) using Grad*Token attribution.

    Returns:
      patch_importance: (Hp, Wp) tensor on CPU (mean over batches)

    Notes:
    - Works for regression: choose which trait output to explain via target_index.
    - Importance is per token (patch). This gives you time-frequency regions importance.

    How it works:
      tokens = encoder_output (B,T,C) (we already store model._last_tokens in forward)
      score = outputs[:, target_index].sum()
      grads = d(score)/d(tokens)
      imp_token = mean_c( abs(grads * tokens) )  (or mean_c(grads * tokens) if use_abs=False)
    """
    model.eval()

    accum: Optional[torch.Tensor] = None
    count = 0

    for batch_i, (scalograms, traits, trait_masks, coi_mask) in enumerate(dataloader):
        if batch_i >= num_batches:
            break

        scalograms = scalograms.to(device, non_blocking=True)
        coi_mask = None if coi_mask is None else coi_mask.to(device, non_blocking=True)

        # forward with grad tracking
        model.zero_grad(set_to_none=True)
        for p in model.parameters():
            p.grad = None

        outputs = model(scalograms, coi_mask=coi_mask)  # sets model._last_tokens
        if model._last_tokens is None:
            raise RuntimeError("model._last_tokens was not set. Did forward run?")

        tokens = model._last_tokens  # (B,T,C)
        tokens.retain_grad()

        # scalar objective for chosen trait
        score = outputs[:, target_index].sum()
        score.backward()

        grads = tokens.grad  # (B,T,C)
        if grads is None:
            raise RuntimeError("No grads for tokens. Something prevented gradient flow.")

        # token importance
        if use_abs:
            imp = (grads * tokens).abs().mean(dim=-1)  # (B,T)
        else:
            imp = (grads * tokens).mean(dim=-1)        # (B,T)

        # reshape to (Hp,Wp)
        B, _, H, W = scalograms.shape
        Hp, Wp = model.patch_grid(H, W)
        imp = imp.mean(dim=0)                          # mean over batch -> (T,)
        imp = imp.reshape(Hp, Wp).detach()

        if accum is None:
            accum = imp
        else:
            accum = accum + imp
        count += 1

    if accum is None:
        raise RuntimeError("No batches processed for importance.")
    patch_importance = (accum / max(1, count)).cpu()
    return patch_importance
