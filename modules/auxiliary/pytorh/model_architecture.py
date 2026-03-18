#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
DELTAS - ResNet-50 for Scalogram Regression

This module provides a ResNet-50 architecture for predicting leaf traits
from 2D CWT scalograms. The model uses ResNet-50 as a feature extractor
with a custom regression head adapted for the task.

Architecture:
1. ResNet-50 backbone (pretrained or random initialization)
2. Custom regression head with optional hidden layer
3. Dropout for regularization

Public API:
- model_architecture: ResNet-50 based model for scalogram regression
- mc_dropout: Enable Monte Carlo dropout for uncertainty estimation
- rmse_loss: Root mean squared error loss with masking
- train: Training loop for one epoch
- validate: Validation loop
- freeze_backbone_model: Transfer learning utility
- make_optimizer: Optimizer factory
"""

from __future__ import annotations
from typing import Optional, List
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.cuda.amp import autocast
from torchvision.models import resnet50, ResNet50_Weights


# ============================================================
# Main Model Architecture
# ============================================================
class model_architecture(nn.Module):
    """
    ResNet-50 based model for scalogram regression.

    Architecture:
    1. Modified first conv layer to accept 1-channel input (grayscale scalograms)
    2. ResNet-50 backbone for feature extraction
    3. Global average pooling
    4. Fully-connected regression head with optional hidden layer

    The ResNet-50 backbone provides:
    - Deep feature extraction through residual connections
    - Multi-scale feature learning through residual blocks
    - Robust representation learning for regression tasks

    Args:
        out_dim: Number of output traits to predict
        dropout_p: Dropout probability (0.0 to 1.0)
        head_hidden: Hidden dimension for regression head (None for direct projection)
        pretrained: Whether to use ImageNet pretrained weights (default: False)
    """

    def __init__(
        self,
        out_dim: int,
        dropout_p: float = 0.25,
        head_hidden: int | None = 512,
        pretrained: bool = False,
    ):
        super().__init__()

        self.out_dim = out_dim
        self.dropout_p = dropout_p

        # Load ResNet-50 backbone
        if pretrained:
            weights = ResNet50_Weights.IMAGENET1K_V2
            backbone = resnet50(weights=weights)
        else:
            backbone = resnet50(weights=None)

        # Modify first conv layer to accept 1-channel input instead of 3-channel RGB
        original_conv1 = backbone.conv1
        self.conv1 = nn.Conv2d(
            1,  # 1 input channel (grayscale scalogram)
            original_conv1.out_channels,
            kernel_size=original_conv1.kernel_size,
            stride=original_conv1.stride,
            padding=original_conv1.padding,
            bias=False
        )

        # If pretrained
        if pretrained:
            with torch.no_grad():
                self.conv1.weight = nn.Parameter(
                    original_conv1.weight.mean(dim=1, keepdim=True)
                )
        else:
            # Initialize with Kaiming normal
            nn.init.kaiming_normal_(self.conv1.weight, mode='fan_out', nonlinearity='relu')

        # Copy remaining layers from backbone
        self.bn1 = backbone.bn1
        self.relu = backbone.relu
        self.maxpool = backbone.maxpool
        self.layer1 = backbone.layer1
        self.layer2 = backbone.layer2
        self.layer3 = backbone.layer3
        self.layer4 = backbone.layer4
        self.avgpool = backbone.avgpool

        # ResNet-50 outputs 2048 features
        feature_dim = 2048

        # Regression head
        if head_hidden is None:
            # Direct projection
            self.head = nn.Sequential(
                nn.Dropout(p=dropout_p),
                nn.Linear(feature_dim, out_dim),
            )
        else:
            # Two-layer head
            self.head = nn.Sequential(
                nn.Dropout(p=dropout_p),
                nn.Linear(feature_dim, head_hidden),
                nn.ReLU(inplace=True),
                nn.Dropout(p=dropout_p),
                nn.Linear(head_hidden, out_dim),
            )

        # Initialize head weights
        self._init_head_weights()

    def _init_head_weights(self):
        """Initialize regression head weights using Kaiming initialization."""
        for m in self.head.modules():
            if isinstance(m, nn.Linear):
                nn.init.kaiming_normal_(m.weight, nonlinearity='relu')
                if m.bias is not None:
                    nn.init.zeros_(m.bias)

    def forward(self, x: torch.Tensor, coi_mask: Optional[torch.Tensor] = None) -> torch.Tensor:
        """
        Forward pass through the ResNet-50 model.

        Args:
            x: Input scalograms of shape (B, 1, H, W)
            coi_mask: Optional mask for cone of influence, shape (B, 1, H, W) or broadcastable

        Returns:
            Predictions of shape (B, out_dim)
        """
        if x.ndim != 4 or x.shape[1] != 1:
            raise ValueError(f"Expected input shape (B, 1, H, W), got {tuple(x.shape)}")

        # Apply cone of influence mask if provided
        if coi_mask is not None:
            coi_mask = coi_mask.to(device=x.device, dtype=x.dtype)

            # Ensure mask has correct dimensions
            if coi_mask.ndim == 2:
                coi_mask = coi_mask.unsqueeze(0).unsqueeze(0)  # (H, W) -> (1, 1, H, W)
            elif coi_mask.ndim == 3:
                coi_mask = coi_mask.unsqueeze(1)  # (B, H, W) -> (B, 1, H, W)
            elif coi_mask.ndim == 4:
                pass  # Already correct shape
            else:
                raise ValueError(f"Unsupported coi_mask shape: {tuple(coi_mask.shape)}")

            x = x * coi_mask

        # ResNet-50 forward pass
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)
        x = self.maxpool(x)

        x = self.layer1(x)
        x = self.layer2(x)
        x = self.layer3(x)
        x = self.layer4(x)

        # Global average pooling
        x = self.avgpool(x)
        x = x.flatten(1)  # (B, 2048)

        # Regression
        x = self.head(x)

        return x

    
# ============================================================
# Monte Carlo Dropout
# ============================================================
def mc_dropout(model: nn.Module, dropout_p: float | None = None):
    """
    Enable dropout at inference time for uncertainty estimation.

    This keeps dropout layers active during inference (training mode) while
    keeping batch normalization layers in evaluation mode.

    Args:
        model: PyTorch model
        dropout_p: Optional new dropout probability to set
    """
    for m in model.modules():
        if isinstance(m, (nn.Dropout, nn.Dropout1d, nn.Dropout2d, nn.Dropout3d)):
            m.train()
            if dropout_p is not None:
                m.p = float(dropout_p)
        elif isinstance(m, (nn.BatchNorm1d, nn.BatchNorm2d, nn.BatchNorm3d,
                           nn.SyncBatchNorm, nn.LayerNorm)):
            m.eval()


# ============================================================
# Loss Function
# ============================================================
def rmse_loss(predictions: torch.Tensor, traits: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    """
    Compute masked root mean squared error.

    Args:
        predictions: Model predictions, shape (B, num_traits)
        traits: Ground truth traits, shape (B, num_traits)
        mask: Binary mask indicating valid traits, shape (B, num_traits)

    Returns:
        Scalar RMSE loss
    """
    squared_diff = (predictions - traits) ** 2
    masked_diff = squared_diff * mask
    mse = masked_diff.sum() / mask.sum().clamp(min=1.0)
    return torch.sqrt(mse)


# ============================================================
# Training and Validation
# ============================================================
def train(model: nn.Module, dataloader, optimizer, device, scaler):
    """
    Training loop for one epoch.

    Args:
        model: PyTorch model
        dataloader: Training data loader
        optimizer: Optimizer
        device: Device (cpu or cuda)
        scaler: GradScaler for mixed precision training

    Returns:
        Average training loss for the epoch
    """
    model.train()
    total_loss = 0.0
    use_amp = device.type == "cuda"

    for scalograms, traits, trait_masks, coi_mask in dataloader:
        # Move data to device
        scalograms = scalograms.to(device, non_blocking=True)
        traits = traits.to(device, non_blocking=True)
        trait_masks = trait_masks.to(device, non_blocking=True)
        coi_mask = None if coi_mask is None else coi_mask.to(device, non_blocking=True)

        # Zero gradients
        optimizer.zero_grad(set_to_none=True)

        # Forward pass with mixed precision
        with autocast(enabled=use_amp):
            outputs = model(scalograms, coi_mask=coi_mask)
            loss = rmse_loss(outputs, traits, trait_masks)

        # Backward pass
        scaler.scale(loss).backward()
        scaler.unscale_(optimizer)
        torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
        scaler.step(optimizer)
        scaler.update()

        total_loss += float(loss.item())

    return total_loss / max(1, len(dataloader))


@torch.no_grad()
def validate(model: nn.Module, dataloader, device):
    """
    Validation loop.

    Args:
        model: PyTorch model
        dataloader: Validation data loader
        device: Device (cpu or cuda)

    Returns:
        Average validation loss
    """
    model.eval()
    total_loss = 0.0
    use_amp = device.type == "cuda"

    for scalograms, traits, trait_masks, coi_mask in dataloader:
        # Move data to device
        scalograms = scalograms.to(device, non_blocking=True)
        traits = traits.to(device, non_blocking=True)
        trait_masks = trait_masks.to(device, non_blocking=True)
        coi_mask = None if coi_mask is None else coi_mask.to(device, non_blocking=True)

        # Forward pass with mixed precision
        with autocast(enabled=use_amp):
            outputs = model(scalograms, coi_mask=coi_mask)
            loss = rmse_loss(outputs, traits, trait_masks)

        total_loss += float(loss.item())

    return total_loss / max(1, len(dataloader))


# ============================================================
# Transfer Learning
# ============================================================
def freeze_backbone_model(
    new_out_cols: List[str],
    old_ckpt_path: str,
    old_out_cols: Optional[List[str]] = None,
    freeze_backbone: bool = False,
    dropout_p: float = 0.2,
    head_hidden: int | None = 512,
    pretrained: bool = False,
) -> nn.Module:
    """
    Load a pretrained model and adapt it for transfer learning.

    This function:
    1. Loads the pretrained model weights
    2. Creates a new model with different output dimension
    3. Copies feature extraction weights (ResNet-50 backbone)
    4. Optionally maps output weights by trait names
    5. Optionally freezes backbone for fine-tuning

    Args:
        new_out_cols: List of trait names for the new model
        old_ckpt_path: Path to pretrained model checkpoint
        old_out_cols: List of trait names from pretrained model (for weight mapping)
        freeze_backbone: If True, freeze feature extractor and only train head
        dropout_p: Dropout probability
        head_hidden: Hidden dimension for regression head
        pretrained: Whether to use ImageNet pretrained weights for new model

    Returns:
        New model with transferred weights
    """
    # Load old model
    old_out_dim = len(old_out_cols) if old_out_cols is not None else 7
    old_model = model_architecture(
        out_dim=old_out_dim,
        dropout_p=dropout_p,
        head_hidden=head_hidden,
        pretrained=False,  # Don't use pretrained for loading checkpoint
    )
    old_sd = torch.load(old_ckpt_path, map_location="cpu")
    old_model.load_state_dict(old_sd, strict=True)

    # Create new model
    new_out_dim = len(new_out_cols)
    new_model = model_architecture(
        out_dim=new_out_dim,
        dropout_p=dropout_p,
        head_hidden=head_hidden,
        pretrained=pretrained,
    )

    # Copy weights
    new_sd = new_model.state_dict()
    old_sd = old_model.state_dict()

    # Find the last linear layer keys (output layer)
    last_weight_key = None
    last_bias_key = None
    for key in old_sd.keys():
        if 'head' in key and key.endswith('.weight'):
            last_weight_key = key
        if 'head' in key and key.endswith('.bias'):
            last_bias_key = key

    # Copy all weights except the final output layer
    for key, value in old_sd.items():
        if key == last_weight_key or key == last_bias_key:
            continue
        if key in new_sd and new_sd[key].shape == value.shape:
            new_sd[key] = value

    # Map output layer weights by trait names if provided
    if old_out_cols is not None and last_weight_key is not None:
        old_weight = old_sd[last_weight_key]
        old_bias = old_sd[last_bias_key]
        new_weight = new_sd[last_weight_key]
        new_bias = new_sd[last_bias_key]

        # Map traits from old to new
        old_name_to_idx = {name: i for i, name in enumerate(old_out_cols)}
        for new_idx, trait_name in enumerate(new_out_cols):
            if trait_name in old_name_to_idx:
                old_idx = old_name_to_idx[trait_name]
                new_weight[new_idx] = old_weight[old_idx]
                new_bias[new_idx] = old_bias[old_idx]

        new_sd[last_weight_key] = new_weight
        new_sd[last_bias_key] = new_bias

    # Load state dict
    new_model.load_state_dict(new_sd, strict=False)

    # Optionally freeze backbone (everything except head)
    if freeze_backbone:
        for name, param in new_model.named_parameters():
            if not name.startswith('head.'):
                param.requires_grad = False

    return new_model


# ============================================================
# Optimizer
# ============================================================
def make_optimizer(
    model: nn.Module,
    base_lr: float = 1e-3,
    weight_decay: float = 1e-4
) -> torch.optim.Optimizer:
    """
    Create an AdamW optimizer for the model.

    Args:
        model: PyTorch model
        base_lr: Learning rate
        weight_decay: L2 regularization weight

    Returns:
        AdamW optimizer
    """
    return torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=base_lr,
        weight_decay=weight_decay
    )
