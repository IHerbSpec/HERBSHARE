FROM rocker/shiny:4.5.3

# System dependencies (GDAL/GEOS/PROJ for sf; build tools for Python packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Python: isolated venv at /opt/venv so it never conflicts with system Python
RUN python3 -m venv /opt/venv
ENV HERBSPHERE_PYTHON=/opt/venv/bin/python3

COPY requirements.txt /tmp/requirements.txt

# CPU-only PyTorch wheels (~500 MB vs ~2 GB for CUDA builds)
RUN /opt/venv/bin/pip install --no-cache-dir \
    torch==2.10.0 torchvision==0.25.0 \
    --index-url https://download.pytorch.org/whl/cpu

# Remaining packages (numpy, polars, PyWavelets) from requirements.txt
RUN grep -vE "^(torch|torchvision)" /tmp/requirements.txt | \
    /opt/venv/bin/pip install --no-cache-dir -r /dev/stdin

# R packages (install before copying app so layer is cached on reruns)
RUN R -e "install.packages(c( \
    'shinythemes', 'shinycssloaders', 'bslib', 'bsicons', \
    'leaflet', 'leaflet.extras', \
    'data.table', 'sf', 'dplyr', 'tidyr', \
    'shinyjs', 'plotly', 'DT', \
    'future', 'promises' \
  ), repos='https://cloud.r-project.org/')"

# Only copy the files the running app actually needs
COPY app.R                  /srv/shiny-server/
COPY modules/               /srv/shiny-server/modules/
COPY data/01-spectra/     /srv/shiny-server/data/01-spectra/
COPY data/02-organized/     /srv/shiny-server/data/02-organized/
COPY www/                   /srv/shiny-server/www/
COPY shiny-server.conf      /etc/shiny-server/shiny-server.conf

# Shiny Server runs as 'shiny'; make files readable
RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
