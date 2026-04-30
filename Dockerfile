FROM rocker/shiny:4.5.3

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    gfortran \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    libsqlite3-dev \
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

# Python venv
RUN python3 -m venv /opt/venv
ENV HERBSPHERE_PYTHON=/opt/venv/bin/python3

COPY requirements.txt /tmp/requirements.txt

RUN /opt/venv/bin/pip install --no-cache-dir \
    torch==2.10.0 torchvision==0.25.0 \
    --index-url https://download.pytorch.org/whl/cpu

RUN grep -vE "^(torch|torchvision)" /tmp/requirements.txt | \
    /opt/venv/bin/pip install --no-cache-dir -r /dev/stdin

# Install R packages
RUN R -e "install.packages(c( \
    'shinythemes', \
    'shinycssloaders', \
    'bslib', \
    'bsicons', \
    'data.table', \
    'dplyr', \
    'tidyr', \
    'shinyjs', \
    'plotly', \
    'DT', \
    'future', \
    'promises', \
    'sf', \
    'leaflet', \
    'leaflet.extras' \
  ), repos='https://cloud.r-project.org', Ncpus = parallel::detectCores())"

COPY app.R                  /srv/shiny-server/
COPY modules/               /srv/shiny-server/modules/
COPY data/01-spectra/       /srv/shiny-server/data/01-spectra/
COPY data/02-organized/     /srv/shiny-server/data/02-organized/
COPY www/                   /srv/shiny-server/www/
COPY shiny-server.conf      /etc/shiny-server/shiny-server.conf

RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]