# HERBSPHERE

**HERBSPHERE — Herbarium Spectral Hub for Research and Exploration**

The digitization of specimen data—the conversion of physical samples into accessible 
digital content—combined with data science workflows is driving the discovery and 
use of herbarium collections at an unprecedented scale. **HERBSPHERE**—HERBerbarium 
SPectral Hub for Research and Exploration—aims to advance the next generation 
of specimen digitization through the exploration and use of reflectance 
spectroscopy data from herbarium specimens.

Leaf spectroscopy has emerged as a powerful tool for rapid leaf phenotyping. 
As a non-destructive technique, it can provide insights into ecological and 
evolutionary patterns across spatial and temporal scales, enabling the 
estimation of leaf traits such as cellulose, lignin, and leaf mass per area, 
among others, as well as uncovering patterns of species diversification 
through spectral information. Most importantly, the use of spectroscopy on 
herbarium specimens has the potential to transform these vast plant 
collections into dynamic laboratories for addressing pressing scientific 
and environmental challenges.

---

### Requirements

| Dependency | Minimum version |
|------------|----------------|
| R          | 4.2.0          |
| Python     | 3.12           |

---

### Installation

#### 1. Clone the repository

```bash
git clone https://github.com/IHerbSpec/HERBSPHERE.git
cd HERBSPHERE
```

#### 2. Install R packages

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

#### 3. Install Python dependencies

##### Using `pyproject.toml`

```bash
pip install .
```

##### GPU support (optional)

By default, PyTorch is installed for CPU only. For GPU support, visit [pytorch.org/get-started/locally](https://pytorch.org/get-started/locally/) to get the installation command for your CUDA version, then run it **before** installing the other dependencies.

---

### Running the app

Open R or RStudio and run:

```r
shiny::runApp()
```

Or launch `app.R` directly from RStudio using the **Run App** button.

---

### Citation

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

### Funding

The development of **HERBSPHERE** is supported by:

<div align="center">
  <img src="www/HUH_black.png" height="90px" style="background:#ffffff; padding:8px; border-radius:5px;">
  &nbsp;&nbsp;&nbsp;
  <img src="www/HDSI_black.png" height="90px" style="background:#ffffff; padding:8px; border-radius:5px;">
</div>

---

## Licence

HERBSPHERE is released under the [MIT License](https://opensource.org/licenses/MIT).
