# HERBSPHERE

**HERBSPHERE** — Herbarium Spectral Hub for Research and Exploration

A Shiny application for the exploration of reflectance spectroscopy data from herbarium 
specimens and prediction of leaf traits.

---

## Requirements

| Dependency | Minimum version |
|------------|----------------|
| R          | 4.2.0          |
| Python     | 3.12           |

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/IHerbSpec/HERBSPHERE.git
cd HERBSPHERE
```

### 2. Install R packages

Open R or RStudio and run:

```r
source("install_packages.R")
```

This installs all required R packages:

| Package | Purpose |
|---------|---------|
| shiny, bslib, bsicons, shinythemes, shinycssloaders, shinyjs | UI framework |
| data.table, dplyr, tidyr | Data manipulation |
| plotly, DT, leaflet, leaflet.extras | Visualization |
| sf | Spatial data |
| rgbif, tidygeocoder | Biodiversity data |
| httr2, jsonlite | Web and API |
| future, promises | Async execution |

### 3. Install Python dependencies

#### Option A — using `pyproject.toml` (recommended)

```bash
pip install .
```

#### Option B — using `requirements.txt`

```bash
pip install -r requirements.txt
```

#### GPU support (optional)

By default, PyTorch is installed for CPU only. For GPU support, visit [pytorch.org/get-started/locally](https://pytorch.org/get-started/locally/) to get the installation command for your CUDA version, then run it **before** installing the other dependencies.

---

## Running the app

Open R or RStudio and run:

```r
shiny::runApp()
```

Or launch `app.R` directly from RStudio using the **Run App** button.

---

## Citation

If you use HERBSPHERE in your research, please cite:

```bibtex
@software{HERBSPHERE,
  author  = {Guzmán J.A., White D. and Cavender-Bares J.},
  title   = {HERBSPHERE: Herbaria Spectral Hub for Research and Exploration},
  year    = {2026},
  version = {0.1},
  url     = {https://github.com/IHerbSpec/HERBSPHERE}
}
```

---

## Licence

HERBSPHERE is released under the [MIT License](https://opensource.org/licenses/MIT).
