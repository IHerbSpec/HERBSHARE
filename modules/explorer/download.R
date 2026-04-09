################################################################################
### Download bundle

# UI
download_ui <- function(id) {
  ns <- NS(id)
  tagList(

    # Full-screen spinner overlay — shown while ZIP is being prepared
    tags$div(
      id = ns("zip_overlay"),
      style = paste(
        "display:none;",
        "position:fixed; top:0; left:0; width:100%; height:100%;",
        "background:rgba(0,0,0,0.55);",
        "z-index:99999;",
        "justify-content:center; align-items:center;"
      ),
      tags$div(
        style = "text-align:center; color:#ffffff;",
        tags$div(
          class = "spinner-border",
          style = "width:3.5rem; height:3.5rem; border-width:0.35em;",
          role  = "status",
          tags$span(class = "visually-hidden", "Loading...")
        ),
        tags$p(
          style = "margin-top:1rem; font-size:1.1rem; font-weight:600;",
          "Preparing download\u2026"
        ),
        tags$p(
          style = "font-size:0.85rem; opacity:0.75;",
          "This may take a few seconds for large selections."
        )
      )
    ),

    # JavaScript: show overlay on click; hide when OS save-dialog is dismissed
    tags$script(HTML(sprintf("
      (function() {
        var overlayId  = '%s';
        var safetyMs   = 300000; // 5-minute hard timeout
        var safetyTimer = null;

        function showOverlay() {
          var el = document.getElementById(overlayId);
          if (el) el.style.display = 'flex';
        }

        function hideOverlay() {
          var el = document.getElementById(overlayId);
          if (el) el.style.display = 'none';
          if (safetyTimer) { clearTimeout(safetyTimer); safetyTimer = null; }
          window.removeEventListener('focus', onWindowFocus);
        }

        function onWindowFocus() {
          hideOverlay();
        }

        // Event delegation: works even though the button is rendered dynamically
        document.addEventListener('click', function(e) {
          var t = e.target;
          // Walk up in case user clicks the icon inside the <a>
          while (t && t !== document.body) {
            if (t.id && t.id.match(/download_zip$/)) {
              showOverlay();
              safetyTimer = setTimeout(hideOverlay, safetyMs);
              // Wait briefly before attaching focus listener so the click
              // itself does not immediately re-trigger it
              setTimeout(function() {
                window.addEventListener('focus', onWindowFocus);
              }, 800);
              break;
            }
            t = t.parentElement;
          }
        });
      })();
    ", ns("zip_overlay")))),

    uiOutput(ns("btn"))
  )
}

# Server
download_server <- function(id, applied_data, spectra_compiled, citation, on_show, on_hide) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Visibility toggled
    visible <- reactiveVal(FALSE)
    observeEvent(on_show(), { visible(TRUE)  }, ignoreInit = TRUE)
    observeEvent(on_hide(), { visible(FALSE) }, ignoreInit = TRUE)

    # Applied metadata as data.frame (drop geometry ifsf)
    sel_md <- reactive({
      req(visible())
      x <- if(shiny::is.reactive(applied_data)) applied_data() else applied_data
      if(inherits(x, "sf")) x <- sf::st_drop_geometry(x)
      x
    })

    # Spectra subset — only free (non-embargoed) rows
    sel_spectra <- reactive({
      md <- sel_free()
      if(!isTRUE(nrow(md) > 0)) return(spectra_compiled[0, ])
      if(!"filename" %in% names(md)) return(spectra_compiled[0, ])
      dplyr::filter(spectra_compiled, filename %in% md$filename)
    })

    # Split selected data into free and embargoed subsets
    sel_free <- reactive({
      md <- sel_md()
      if (!"embargo" %in% names(md)) return(md)
      embargoed_flag <- as.logical(md$embargo)
      md[!embargoed_flag | is.na(embargoed_flag), ]
    })

    sel_embargoed <- reactive({
      md <- sel_md()
      if (!"embargo" %in% names(md)) return(md[0, ])
      embargoed_flag <- as.logical(md$embargo)
      md[!is.na(embargoed_flag) & embargoed_flag, ]
    })

    # Overlay panel inside map container
    output$btn <- renderUI({
      if(!isTRUE(visible())) return(NULL)
      md <- sel_md()
      if(!isTRUE(nrow(md) > 0)) return(NULL)

      tags$div(
        style = "position:absolute; right: 1rem; bottom: 1rem; z-index: 500;",
        downloadButton(ns("download_zip"), "Download selected (.zip)", class = "btn btn-success")
      )
    })

    observeEvent(input$hide_panel, { visible(FALSE) }, ignoreInit = TRUE)

    # ── Helpers ────────────────────────────────────────────────────────────────

    # Build CITEME.txt content
    # md          — full selection (all rows, for citation matching)
    # citation_df — citation lookup table
    # has_embargo — TRUE if any row in the selection is embargoed
    build_citeme <- function(md, citation_df, has_embargo) {
      herbsphere <- paste(
        "Guzman J.A., White D. and Cavender-Bares J. 2026. HERBSPHERE: Herbaria Spectral Hub for Research and Exploration. Version 0.1. URL: https://github.com/IHerbSpec/HERBSPHERE",
        sep = "\n"
      )

      lines <- c(
        "HERBSPHERE - Data Citation File",
        "================================",
        paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
        "",
        "SOFTWARE",
        "--------",
        herbsphere,
        ""
      )

      # Normalize citation_df to plain data.frame and use character keys for matching
      if (!is.null(citation_df) && nrow(citation_df) > 0) {
        citation_df <- as.data.frame(citation_df)
        citation_df$referenceInfo <- as.character(citation_df$referenceInfo)
      }

      if(has_embargo) {
        lines <- c(lines,
          "EMBARGO NOTICE",
          "--------------",
          "One or more datasets in your selection are currently under embargo.",
          "The data files have not been included in this download.",
          ""
        )

        # Per-dataset embargo messages from citation table
        if (!is.null(citation_df) && nrow(citation_df) > 0 &&
            "referenceInfo" %in% names(md) && "Embargo_citation" %in% names(citation_df)) {
          ref_ids <- as.character(unique(md$referenceInfo))
          ref_ids <- ref_ids[!is.na(ref_ids) & nzchar(ref_ids)]
          matched  <- citation_df[citation_df$referenceInfo %in% ref_ids, , drop = FALSE]
          emb_msgs <- unique(matched$Embargo_citation[!is.na(matched$Embargo_citation) & nzchar(matched$Embargo_citation)])
          for (msg in emb_msgs) {
            lines <- c(lines, paste0("- ", msg))
          }
          if (length(emb_msgs) > 0) lines <- c(lines, "")
        }
      }

      # Match citation rows by referenceInfo
      if("referenceInfo" %in% names(md) && !is.null(citation_df) && nrow(citation_df) > 0) {
        ref_ids <- as.character(unique(md$referenceInfo))
        ref_ids <- ref_ids[!is.na(ref_ids) & nzchar(ref_ids)]
        matched  <- citation_df[citation_df$referenceInfo %in% ref_ids, , drop = FALSE]

        if(nrow(matched) > 0) {
          # Unique spectral data citations
          spectral_cites <- unique(matched$Iherbspec_citation[
            !is.na(matched$Iherbspec_citation) & nzchar(matched$Iherbspec_citation)
          ])
          if(length(spectral_cites) > 0) {
            lines <- c(lines, "SPECTRAL DATA", "-------------", "")
            for (i in seq_along(spectral_cites)) {
              lines <- c(lines, paste0(i, ". ", spectral_cites[i]), "")
            }
          }

          # Unique occurrence data citations
          occurrence_cites <- unique(matched$Occurrence_citation[
            !is.na(matched$Occurrence_citation) & nzchar(matched$Occurrence_citation)
          ])
          if(length(occurrence_cites) > 0) {
            lines <- c(lines, "OCCURRENCE DATA (GBIF)", "----------------------", "")
            for (i in seq_along(occurrence_cites)) {
              lines <- c(lines, paste0(i, ". ", occurrence_cites[i]), "")
            }
          }
        }
      }

      paste(lines, collapse = "\n")
    }

    # Locate spectra files by basename under a base directory
    find_spectra_files <- function(filenames, base_dir) {
      filenames <- unique(filenames[!is.na(filenames) & nzchar(filenames)])
      if(length(filenames) == 0 || !dir.exists(base_dir)) return(character(0))
      all_paths  <- list.files(base_dir, recursive = TRUE, full.names = TRUE)
      all_paths[basename(all_paths) %in% filenames]
    }

    # ── ZIP handler ────────────────────────────────────────────────────────────
    output$download_zip <- downloadHandler(
      filename = function() {
        paste0("HERBSPHERE_data-selection_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".zip")
      },
      
      content = function(file) {
        md        <- sel_md()
        validate(need(nrow(md) > 0, "No rows selected to download."))
        free_md     <- sel_free()
        has_embargo <- nrow(sel_embargoed()) > 0

        tmpdir <- tempfile("herbsel_")
        dir.create(tmpdir)

        # Always include CITEME.txt (covers full selection for citation credit)
        # useBytes = TRUE writes raw bytes without encoding conversion, which
        # avoids the "invalid char string in output conversion" warning on
        # Windows when citation strings contain UTF-8 curly quotes.
        cat(build_citeme(md, citation, has_embargo),
            file = file.path(tmpdir, "CITEME.txt"),
            useBytes = TRUE)

        zip_files <- "CITEME.txt"

        if(nrow(free_md) > 0) {
          # metadata CSV — free rows only
          data.table::fwrite(free_md, file.path(tmpdir, "metadata_selected.csv"))

          # spectra summary CSV — free rows only
          data.table::fwrite(sel_spectra(), file.path(tmpdir, "spectra_selected.csv"))

          zip_files <- c(zip_files, "metadata_selected.csv", "spectra_selected.csv")

          # Raw spectra files — free rows only
          spectra_base <- file.path("data", "01-spectra", "02-spectra")
          raw_filenames <- unique(c(
            if("filename"           %in% names(free_md)) free_md$filename           else NULL,
            if("backgroundFilename" %in% names(free_md)) free_md$backgroundFilename else NULL,
            if("whiteRefFilename"   %in% names(free_md)) free_md$whiteRefFilename   else NULL
          ))

          src_paths <- find_spectra_files(raw_filenames, spectra_base)
          if(length(src_paths) > 0) {
            spec_dir <- file.path(tmpdir, "spectra_files")
            dir.create(spec_dir)
            file.copy(src_paths, file.path(spec_dir, basename(src_paths)))
            zip_files <- c(zip_files, "spectra_files")
          }
        }

        # Zip from inside tmpdir so paths inside the archive are relative
        oldwd <- setwd(tmpdir)
        on.exit(setwd(oldwd), add = TRUE)

        if(requireNamespace("zip", quietly = TRUE)) {
          zip::zipr(zipfile = file, files = zip_files)
        } else {
          utils::zip(zipfile = file, files = zip_files)
        }
      }
    )
  })
}
