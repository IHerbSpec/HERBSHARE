# PyTorch Models for HERBSPHERE

This directory contains the pretrained deep learning models for leaf trait prediction.

## Files

- `model_architecture.py` - Patch-wise Transformer model architecture (DELTAS)
- `dataset_definition.py` - Dataset and data loading utilities
- `boxcox_utils.py` - Box-Cox transformation utilities for normalization
- `finetune_regression_model.pth` - Pretrained model weights
- `finetune_trait_stats.json` - Normalization statistics for traits
- `03a-model_finetune.py` - Training script (for reference)
- `03b-predict_finetune.py` - Standalone prediction script (for reference)

## Python Environment Requirements

```bash
# Required packages
pip install torch numpy polars pywt scipy tqdm
```

### Package versions (tested):
- torch >= 2.0.0
- numpy >= 1.24.0
- polars >= 0.18.0
- pywt >= 1.4.1
- scipy >= 1.10.0

## Model Architecture

The model uses a patch-wise Transformer that operates on Continuous Wavelet Transform (CWT) scalograms of reflectance spectra.

**Input**: Spectral reflectance (450-2399 nm)
**Output**: 12 leaf functional traits

### Predicted Traits

1. **LMA** - Leaf Mass per Area (g/m²)
2. **EWT** - Equivalent Water Thickness (g/m²)
3. **LDMC** - Leaf Dry Matter Content (fraction)
4. **Car** - Carotenoids (μg/cm²)
5. **Chla** - Chlorophyll a (μg/cm²)
6. **Chlb** - Chlorophyll b (μg/cm²)
7. **Chla+b** - Total Chlorophyll (μg/cm²)
8. **Hemicellulose** - Hemicellulose content (fraction)
9. **Cellulose** - Cellulose content (fraction)
10. **Lignin** - Lignin content (fraction)
11. **N** - Nitrogen content (fraction)
12. **C** - Carbon content (fraction)

## Usage from R

The Engine module in HERBSPHERE automatically calls these models via the `engine_predict.py` wrapper script.

For manual testing:

```r
source("modules/auxiliary/predict_traits.R")

predictions <- predict_traits_python(
  reflectance_path = "path/to/spectra.csv",
  target_traits = c("LMA", "EWT", "LDMC"),
  use_uncertainty = FALSE
)
```

## Usage from Python (standalone)

```bash
python3 modules/auxiliary/engine_predict.py \
  --input path/to/spectra.csv \
  --output predictions.csv \
  --traits LMA,EWT,LDMC \
  --uncertainty
```

## Input Data Format

CSV file with:
- First column: Sample ID (column name: `rowID`)
- Remaining columns: Wavelength bands (450-2399 nm as numeric column names)
- Header row required

Example:
```
rowID,450,451,452,...,2398,2399
sample_001,0.05,0.052,0.054,...,0.32,0.31
sample_002,0.06,0.058,0.056,...,0.28,0.29
```

## Model Details

- **Architecture**: Patch-wise Transformer with CWT scalogram input
- **Patch size**: (2, 5) - scales × wavelengths
- **Embedding dimension**: 256
- **Transformer depth**: 8 layers
- **Attention heads**: 8
- **Training**: Box-Cox normalized targets with masked loss
- **Cone of influence**: Applied to avoid edge artifacts in CWT

## Citation

If you use these models, please cite:

```
[Add your publication citation here]
```
