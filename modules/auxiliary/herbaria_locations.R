################################################################################
##### Function to derive the locations from herbaria
################################################################################

# ------------------------------------------------------------------------------
# Libraries

library(data.table)
library(rgbif)
library(httr2)
library(jsonlite)

# ------------------------------------------------------------------------------
# Function

# API location
gbif_base <- "https://api.gbif.org/v1"

# API function
gbif_pager <- function(path, query = list(), page_size = 1000L, max_pages = 1000L) {
  out <- vector("list", max_pages)
  offset <- 0L
  i <- 1L
  repeat {
    req <- request(paste0(gbif_base, path)) |>
      req_url_query(limit = page_size, offset = offset, !!!query)
    resp <- req_perform(req)
    dat  <- resp_body_string(resp) |> fromJSON(flatten = TRUE)
    if (!length(dat$results)) break
    out[[i]] <- as.data.table(dat$results)
    if (nrow(out[[i]]) < page_size || i >= max_pages) break
    offset <- offset + page_size; i <- i + 1L
  }
  rbindlist(out[seq_len(i)], use.names = TRUE, fill = TRUE)
}

# Get location of herbaria
inst <- gbif_pager(
  path  = "/grscicoll/institution",
  query = list(type = "HERBARIUM")
)

pick <- function(dt, cols) dt[, intersect(cols, names(dt)), with = FALSE]

# Select key columns
inst_keep <- pick(inst, c("code","name", "latitude","longitude"))
setnames(inst_keep,  old = c("code","name"),
         new = c("institutionCode","institutionName"))

# Export locations
fwrite(inst_keep, "data/locations/hebaria_locations.csv")
