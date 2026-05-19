# HERBSHARE

<div align="center">

**HERBarium Spectral Hub for Advancing Research and Exploration**

<a href="https://doi.org/10.5281/zenodo.20278893"><img src="https://zenodo.org/badge/1016310857.svg" alt="DOI"></a>
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub](https://img.shields.io/badge/GitHub-IHerbSpec%2FHERBSHARE-brightgreen)](https://github.com/IHerbSpec/HERBSHARE)

</div>

---

## Summary

**HERBSHARE** — HERBarium Spectral Hub for Advancing Research and Exploration — is an interactive web application designed to advance the next generation of herbarium specimen digitization through reflectance spectroscopy. The application provides a user-friendly interface for taxonomists, botanists, and ecologists to:

- **Explore** the IHerbSpec database of herbarium spectral records through an interactive map, filter specimens by taxonomy, geography, and collection metadata, and visualize individual spectra and specimen images
- **Predict** leaf functional traits from uploaded spectral reflectance data using an universal deep-learning model trained and validated on herbarium spectra

HERBSHARE bridges the gap between large herbarium collections and practical spectral analysis, making trait estimation from museum specimens accessible without extensive programming knowledge.

---

## Repository Description

This repository contains the complete source code for the HERBSHARE application organized into modular components:

### Project Structure

```
HERBSHARE/
├── app.R                           # Main application file
├── modules/                        # Application modules
│   ├── explorer_panel.R            # Explorer panel (UI + server)
│   ├── engine_panel.R              # Engine panel (UI + server)
│   ├── about_panel.R               # About panel
│   ├── explorer/                   # Explorer sub-modules
│   │   ├── select_by.R             # Geospatial and taxonomic filters
│   │   ├── records_summary.R       # Summary statistics of filtered records
│   │   ├── map.R                   # Interactive Leaflet map
│   │   ├── specimen_selection.R    # Specimen metadata, spectra, and images
│   │   └── download.R              # ZIP download of selected data
│   ├── engine/                     # Engine sub-modules
│   │   ├── upload_spectra.R        # File upload and validation
│   │   ├── trait_selector.R        # Trait selection interface
│   │   ├── spectra_viewer.R        # Uploaded spectra visualization
│   │   ├── predictions_output.R    # Results table and CSV download
│   │   ├── predict_traits.R        # R wrapper for Python inference
│   │   └── trait_visualization.R   # Interactive histograms and plot export
│   └── auxiliary/                  # Shared utility functions and model files
│       ├── engine_predict.py       # Python inference script (PyTorch)
│       ├── herbaria_locations.R    # Herbaria location data loader
│       ├── HERBSHARE_metadata.R   # Metadata loader
│       ├── read_spectra.R          # Spectra reader
│       └── pytorh/                 # Pretrained model weights and stats
├── data/                           # Application data
├── www/                            # Static assets (images, CSS)
├── requirements.txt                # Python dependencies
├── google-analytics.html           # Google analytics tracker
├── DESCRIPTION                     # R description project
├── LICENSE                         # MIT License
└── README.md                       # This file
```

### Key Features

#### 1. **Explorer Module**

The Explorer allows users to navigate the IHerbSpec spectral database of herbarium specimens through an interactive interface:

- **Select by** — Filter specimens by geospatial attributes (country, state/province) and taxonomic metadata using dynamic dropdowns; refine spatially by drawing polygons directly on the map
- **Records summary** — Live summary statistics of the currently displayed filtered set of records
- **Interactive map** — Leaflet-based map showing specimen collection localities; click any point to open the specimen panel
- **Specimen panel** — On-click sidebar displaying specimen metadata, reflectance spectra profile, and digitized herbarium sheet image
- **Download** — Export the current selection (metadata + spectra) as a bundled `.zip` file, including a data citation file

#### 2. **Engine Module**

The Engine provides a prediction interface for estimating leaf functional traits from spectral reflectance data using a pretrained deep learning model:

- **Upload spectra** — Import spectral reflectance data (`.csv` format) with automatic format validation; wavelength columns must span 450–2399 nm
- **Trait selection** — Choose from 12 leaf functional traits (LMA, EWT, LDMC, carotenoids, chlorophyll a/b, total chlorophyll, hemicellulose, cellulose, lignin, nitrogen, carbon), with select/clear all shortcuts
- **Spectra viewer** — Visualize uploaded spectra before running predictions
- **Predictions table** — Interactive data table of trait predictions with CSV download
- **Trait visualization** — Interactive histograms per predicted trait
- **Backend** — Inference pipeline for PyTorch

---

## Requirements

### System Requirements

- **R version**: ≥ 4.2.0
- **Python version**: ≥ 3.12
- **Operating System**: Windows or Linux

### R Packages

All required R packages are listed in [`DESCRIPTION`](DESCRIPTION). They are installed automatically during deployment.

### Python Packages

All required Python packages and their pinned versions are listed in [`requirements.txt`](requirements.txt). GPU support for PyTorch is optional; see [pytorch.org/get-started/locally](https://pytorch.org/get-started/locally/) for CUDA-specific installation instructions.

---

## Citation

If you use HERBSHARE in your research, please cite:

Guzmán J.A., White D., and Cavender-Bares J. (2026). *HERBSHARE: HERBarium Spectral Hub for Advancing Research and Exploration*. Zenodo. https://doi.org/10.5281/zenodo.20278894

### BibTeX Entry

```bibtex

@software{HERBSHARE,
  author = {Guzmán J.A., White D., and Cavender-Bares J.},
  title = {HERBSHARE: HERBarium Spectral Hub for Advancing Research and Exploration},
  year = {2026},
  version = {v0.1-beta},
  publisher = {Zenodo},
  url = {https://github.com/IHerbSpec/HERBSHARE},
  doi = {https://doi.org/10.5281/zenodo.20278894}
}

```

---

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

---

## Reporting Issues

If you encounter bugs or have feature requests, please open an issue on the [GitHub Issues page](https://github.com/IHerbSpec/HERBSHARE/issues).

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Contact

**Author:** J. Antonio Guzmán Q.
**Email:** aguzman@fas.harvard.edu
**Institution:** Harvard University

---

## Acknowledgements

The development of **HERBSHARE** is supported/funded by:

<div align="center">

  <img src="www/HUH_black.png" height="130px"><br><br>

  <img src="www/HDSI_black.png" height="60px">
  <img src="www/FAS_black.png" height="60px"><br><br>

  <img src="www/ASCEND.png" height="120px">
  <img src="www/NSF.png" height="120px">

</div>

---

<div align="center">

**Version 0.1** | **Last Updated:** 2026-05-05

</div>
