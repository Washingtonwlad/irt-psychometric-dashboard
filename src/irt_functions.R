# =============================================================================
# Reusable IRT helper functions
# Project: IRT Psychometric Dashboard - PISA 2022
# Author: Washington Casamen Nolasco
# =============================================================================

find_project_root <- function(start = getwd()) {
  candidates <- unique(normalizePath(
    c(start, file.path(start, ".."), file.path(start, "../..")),
    winslash = "/",
    mustWork = FALSE
  ))

  for (path in candidates) {
    has_readme <- file.exists(file.path(path, "README.md"))
    has_data <- dir.exists(file.path(path, "data"))
    has_src <- dir.exists(file.path(path, "src"))

    if (has_readme && has_data && has_src) {
      return(path)
    }
  }

  stop(
    "Project root not found. Run from the repository root or from app/.",
    call. = FALSE
  )
}

required_cache_files <- function(project_root = find_project_root()) {
  file.path(
    project_root,
    "data",
    "processed",
    c(
      "model_1pl.rds",
      "model_2pl.rds",
      "dif_results.rds"
    )
  )
}

load_cached_irt_objects <- function(project_root = find_project_root()) {
  cache_files <- required_cache_files(project_root)
  missing_files <- cache_files[!file.exists(cache_files)]

  if (length(missing_files) > 0) {
    stop(
      paste(
        "Missing cached model files.",
        "Run analysis/irt_analysis.qmd first or restore data/processed/.",
        "Missing:",
        paste(missing_files, collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  list(
    model_1pl = readRDS(cache_files[1]),
    model_2pl = readRDS(cache_files[2]),
    dif_df = readRDS(cache_files[3])
  )
}

extract_2pl_parameters <- function(model_2pl, dif_df = NULL) {
  params <- mirt::coef(model_2pl, IRTpars = TRUE, simplify = TRUE)$items
  params <- as.data.frame(params)
  params$item <- rownames(params)

  if (!is.null(dif_df)) {
    params <- dplyr::left_join(
      params,
      dplyr::select(dif_df, item, dif_flag, X2, adj_p),
      by = "item"
    )
  }

  params
}

icc_2pl <- function(a, b, theta) {
  1 / (1 + exp(-a * (theta - b)))
}

iif_2pl <- function(a, b, theta) {
  p <- icc_2pl(a, b, theta)
  a^2 * p * (1 - p)
}

build_tif_data <- function(params_2pl, theta_seq = seq(-4, 4, length.out = 300)) {
  item_information <- do.call(rbind, lapply(seq_len(nrow(params_2pl)), function(i) {
    data.frame(
      theta = theta_seq,
      info = iif_2pl(params_2pl$a[i], params_2pl$b[i], theta_seq)
    )
  }))

  item_information |>
    dplyr::group_by(theta) |>
    dplyr::summarise(total_info = sum(info), .groups = "drop") |>
    dplyr::mutate(se = 1 / sqrt(total_info))
}
