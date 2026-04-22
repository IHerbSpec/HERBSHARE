# Engine Module

The Engine module provides an interface for predicting leaf functional traits from spectral reflectance data using pretrained deep learning models.

## Overview

The Engine module allows users to:
1. **Upload** spectral reflectance data (CSV format)
2. **Select** which traits to predict from 12 available traits
3. **Predict** traits using a pretrained patch-wise Transformer model
4. **Download** predictions with optional uncertainty estimates

## Module Structure

```
engine/
├── upload_spectra.R          # File upload and validation
├── trait_selector.R          # Trait selection interface
├── predictions_output.R      # Results display and download
├── trait_visualization.R     # Interactive histograms and plot export
├── example_spectra_format.csv # Example data template
└── README.md                 # This file
```

## Usage

### In the Shiny App

1. Navigate to the **Engine** tab
2. Click **Browse** to upload your spectral data CSV file
3. Select traits to predict (or use "Select all")
4. Click **Predict traits** button
5. Wait for predictions to complete
6. View results in two tabs:
   - **Predictions Table**: Interactive data table with CSV download
   - **Visualization**: Histograms of trait distributions with plot downloads

### Data Format Requirements

Your CSV file must have:
- **First column**: Sample ID (any name, but `rowID` is recommended)
- **Remaining columns**: Wavelength bands from 450 to 2399 nm
- **Header row**: Required
- **Values**: Reflectance values (typically 0-1 or 0-100%)

Example structure:
```
rowID,450,451,452,453,...,2397,2398,2399
sample_001,0.05,0.052,0.054,0.056,...,0.31,0.32,0.31
sample_002,0.06,0.058,0.056,0.054,...,0.29,0.28,0.29
sample_003,0.07,0.068,0.066,0.064,...,0.27,0.28,0.27
```

### Available Traits

The model can predict 12 leaf functional traits:

| Trait Code | Description | Units |
|------------|-------------|-------|
| LMA | Leaf Mass per Area | g/m² |
| EWT | Equivalent Water Thickness | g/m² |
| LDMC | Leaf Dry Matter Content | fraction (0-1) |
| Car | Carotenoids | μg/cm² |
| Chla | Chlorophyll a | μg/cm² |
| Chlb | Chlorophyll b | μg/cm² |
| Chla+b | Total Chlorophyll | μg/cm² |
| Hemicellulose | Hemicellulose content | fraction (0-1) |
| Cellulose | Cellulose content | fraction (0-1) |
| Lignin | Lignin content | fraction (0-1) |
| N | Nitrogen content | fraction (0-1) |
| C | Carbon content | fraction (0-1) |

## Module Components

### 1. Upload Spectra (`upload_spectra.R`)

**UI Components:**
- File input widget
- Format instructions
- File status indicator
- Predict button

**Server Functions:**
- Validates uploaded file structure
- Checks for proper wavelength columns
- Stores data in reactive value
- Triggers prediction process

### 2. Trait Selector (`trait_selector.R`)

**UI Components:**
- Checkbox group for all 12 traits
- "Select all" button
- "Clear all" button

**Server Functions:**
- Manages trait selection state
- Returns selected traits as reactive vector

### 3. Predictions Output (`predictions_output.R`)

**UI Components:**
- Status indicator (idle/processing/complete)
- Download button for results
- Interactive data table (DT)

**Server Functions:**
- Calls Python prediction script via R wrapper
- Manages prediction state (loading, error handling)
- Formats and displays results
- Provides CSV download
- Returns predictions data for visualization

### 4. Trait Visualization (`trait_visualization.R`)

**UI Components:**
- Grid of interactive histograms (one per trait)
- Download buttons for PNG and PDF exports
- Statistical overlays (mean, median, SD)

**Server Functions:**
- Creates plotly histograms from prediction data
- Filters out uncertainty columns
- Adds trait labels and units
- Generates static plots for export
- Provides PNG and PDF downloads

## Backend Architecture

```
R (Shiny) → predict_traits.R → engine_predict.py → PyTorch Model → Results
```

### Workflow:

1. **R Shiny** (frontend): User uploads data and selects traits
2. **predict_traits.R** (R wrapper): Validates inputs, prepares temporary files
3. **engine_predict.py** (Python script):
   - Loads reflectance data
   - Computes CWT scalograms
   - Runs model inference
   - Denormalizes predictions
   - Saves results to CSV
4. **Results**: Returned to Shiny app for display and download

## Python Dependencies

The Engine requires Python 3.8+ with the following packages:
- `torch` (PyTorch for deep learning)
- `numpy` (numerical computing)
- `polars` (fast DataFrame operations)
- `pywt` (PyWavelets for CWT)
- `scipy` (Box-Cox transformations)

Install with:
```bash
pip install torch numpy polars pywt scipy
```

## Model Information

- **Architecture**: Patch-wise Transformer operating on CWT scalograms
- **Input**: Reflectance spectra (450-2399 nm)
- **Preprocessing**: Continuous Wavelet Transform with cone-of-influence masking
- **Normalization**: Box-Cox transformation per trait
- **Output**: Denormalized trait predictions

Model files location:
- `modules/auxiliary/pytorh/finetune_regression_model.pth` (weights)
- `modules/auxiliary/pytorh/finetune_trait_stats.json` (normalization stats)

## Error Handling

The module handles several error cases:
- **Missing file**: Clear error message if no file uploaded
- **Invalid format**: Validation of column structure and data types
- **Python errors**: Captured and displayed to user
- **Model loading errors**: Informative messages if model files missing

## Performance Notes

- **Processing time**: ~1-5 seconds per 100 samples (GPU) or ~10-30 seconds (CPU)
- **Batch size**: Default 62 samples per batch
- **Memory**: ~2GB RAM minimum, 4GB+ recommended for large datasets
- **GPU**: Optional but recommended for faster inference

## Extending the Module

### Adding Uncertainty Estimation

To enable MC-Dropout uncertainty:

In `predict_traits.R`:
```r
predictions <- predict_traits_python(
  reflectance_path = temp_input,
  target_traits = selected_traits(),
  use_uncertainty = TRUE  # Add this parameter
)
```

This will add `_q0025`, `_q0975`, and `_uncertainty` columns for each trait.

### Adding New Traits

1. Retrain model with new traits
2. Update `finetune_trait_stats.json`
3. Update `AVAILABLE_TRAITS` in `trait_selector.R`
4. Update `ALL_TRAITS` in `engine_predict.py`

## Troubleshooting

### "Python prediction script failed"
- Check Python is installed: `python3 --version`
- Check packages: `python3 -c "import torch, numpy, polars, pywt"`
- Check file paths in error message

### "No wavelength columns detected"
- Ensure column names are numeric (e.g., 450, 451, ..., 2399)
- Check for proper CSV formatting

### "Prediction output file was not created"
- Check disk space
- Check write permissions on temp directory
- Review Python script output for errors

## Current Features

✅ Upload spectral CSV files with validation
✅ Select from 12 leaf functional traits
✅ Batch prediction using PyTorch model
✅ Interactive results table (DT)
✅ CSV download of predictions
✅ **Interactive histograms for all traits**
✅ **PNG and PDF plot exports**
✅ **Statistical summaries (mean, median, SD)**

## Future Enhancements

Potential additions:
- [ ] Real-time prediction progress bar
- [ ] Scatter plots for trait correlations
- [ ] Box plots for trait comparisons
- [ ] Batch processing for multiple files
- [ ] Uncertainty quantification (MC-Dropout)
- [ ] Export comprehensive report (PDF/HTML)
- [ ] Model selection (multiple pretrained models)
- [ ] Feature importance visualization (attention maps)

## Contact

For issues or questions about the Engine module, please open an issue on the GitHub repository.
