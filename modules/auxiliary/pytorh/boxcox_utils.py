#!/usr/bin/env python3

# %% Functions for normalization

import numpy as np
from scipy.stats import boxcox_normmax

# %% Functions for normalization

EPS = 1e-8

def _safe_boxcox_fit(x: np.ndarray):

    x = np.asarray(x, dtype=np.float64)
    x = x[np.isfinite(x)]  # drop NaN/inf

    if x.size == 0:
        # No data to fit; fall back to identity
        return 1.0, 0.0, False

    # If non-positive values, shift to strictly positive
    min_x = np.min(x)
    shift = 0.0
    if min_x <= 0:
        shift = -min_x + EPS

    x_pos = x + shift

    # If constant after shift, Box-Cox is undefined; use identity
    if np.allclose(x_pos, x_pos[0]):
        return 1.0, shift, False

    try:
        lam = boxcox_normmax(x_pos, method='mle')
        return float(lam), float(shift), True
    except Exception:
        # Fallback to identity transform
        return 1.0, float(shift), False
    
def _apply_boxcox(x: float, lam: float, shift: float):

    xp = x + shift
    if xp <= 0:
        xp = EPS
    if np.isclose(lam, 0.0):
        return np.log(xp)
    elif np.isclose(lam, 1.0):
        return xp  # identity (or nearly)
    else:
        return (np.power(xp, lam) - 1.0) / lam
    
def _has_boxcox_params(st: dict) -> bool:
    """Check if dictionary has Box-Cox transformation parameters."""
    return all(k in st for k in ("lambda", "shift", "trans_mean", "trans_std"))
    
def _inv_boxcox_vec(y: np.ndarray, lam: float) -> np.ndarray:
    y = np.asarray(y, dtype = np.float64)
    if np.isclose(lam, 0.0):
        return np.exp(y)
    elif np.isclose(lam, 1.0):
        return y
    else:
        return np.power(lam * y + 1.0, 1.0 / lam)