# =============================================================================
# Build cached data and model objects for the IRT dashboard.
#
# This script is intentionally separate from the Quarto report because the full
# cache build reads a multi-GB SPSS file and fits computationally expensive IRT
# models. Run it only when the raw PISA file or modeling decisions change.
# =============================================================================

required_packages <- c("haven", "dplyr", "mirt")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing required R packages: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

library(haven)
library(dplyr)
library(mirt)

script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
script_path <- if (length(file_arg) > 0) {
  normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
} else {
  normalizePath("scripts/build_cache.R", winslash = "/", mustWork = TRUE)
}

project_root <- normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE)

raw_path <- file.path(project_root, "data", "raw", "CY08MSP_STU_COG.SAV")
processed_dir <- file.path(project_root, "data", "processed")

if (!file.exists(raw_path)) {
  stop(
    "Raw PISA file not found. Expected: ",
    raw_path,
    "\nDownload the PISA 2022 Cognitive Item Data File from OECD and place it there.",
    call. = FALSE
  )
}

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
set.seed(42)

message("Loading raw PISA file...")
pisa_raw <- haven::read_sav(raw_path)

message("Selecting reading item columns...")
cols_s <- names(pisa_raw)[grepl("^CR.*S$|^DR.*S$", names(pisa_raw))]

value_summary <- lapply(cols_s, function(col) {
  sort(unique(na.omit(as.numeric(pisa_raw[[col]]))))
})
names(value_summary) <- cols_s

dichotomous <- names(value_summary)[
  vapply(value_summary, function(v) identical(v, c(0, 1)), logical(1))
]
dichotomous_clean <- dichotomous[!grepl("VS$", dichotomous)]

message("Building response matrix...")
response_matrix <- pisa_raw |>
  dplyr::select(CNT, CNTSTUID, dplyr::all_of(dichotomous_clean)) |>
  dplyr::mutate(dplyr::across(dplyr::all_of(dichotomous_clean), as.numeric))

saveRDS(response_matrix, file.path(processed_dir, "response_matrix.rds"))

item_data <- response_matrix |>
  dplyr::select(dplyr::all_of(dichotomous_clean))
items_per_student <- rowSums(!is.na(item_data))
valid_students <- response_matrix[items_per_student > 0, ]

item_data_valid <- valid_students |>
  dplyr::select(dplyr::all_of(dichotomous_clean))
items_per_valid <- rowSums(!is.na(item_data_valid))
final_matrix <- valid_students[items_per_valid <= length(dichotomous_clean), ]

saveRDS(final_matrix, file.path(processed_dir, "response_matrix_clean.rds"))

message("Creating proportional development sample...")
sample_ids <- final_matrix |>
  dplyr::group_by(CNT) |>
  dplyr::slice_sample(prop = 30000 / nrow(final_matrix)) |>
  dplyr::ungroup()

sample_dev <- sample_ids |>
  dplyr::select(CNT, CNTSTUID, dplyr::all_of(dichotomous_clean))

saveRDS(sample_dev, file.path(processed_dir, "response_matrix_dev.rds"))

item_matrix <- sample_dev |>
  dplyr::select(dplyr::all_of(dichotomous_clean)) |>
  as.data.frame()

message("Fitting 1PL model...")
model_1pl <- mirt::mirt(
  data = item_matrix,
  model = 1,
  itemtype = "Rasch",
  SE = TRUE,
  verbose = TRUE
)
saveRDS(model_1pl, file.path(processed_dir, "model_1pl.rds"))

message("Fitting 2PL model...")
model_2pl <- mirt::mirt(
  data = item_matrix,
  model = 1,
  itemtype = "2PL",
  SE = TRUE,
  verbose = TRUE
)
saveRDS(model_2pl, file.path(processed_dir, "model_2pl.rds"))

message("Attempting 3PL model for documented comparison...")
model_3pl <- tryCatch(
  mirt::mirt(
    data = item_matrix,
    model = 1,
    itemtype = "3PL",
    SE = TRUE,
    verbose = TRUE
  ),
  error = function(err) err
)
saveRDS(model_3pl, file.path(processed_dir, "model_3pl.rds"))

message("Fitting multigroup model for DIF...")
oecd_countries <- c(
  "AUS", "AUT", "BEL", "CAN", "CHL", "COL", "CRI", "CZE", "DNK", "EST",
  "FIN", "FRA", "DEU", "GRC", "HUN", "ISL", "IRL", "ISR", "ITA", "JPN",
  "KOR", "LVA", "LTU", "LUX", "MEX", "NLD", "NZL", "NOR", "POL", "PRT",
  "SVK", "SVN", "ESP", "SWE", "CHE", "TUR", "GBR", "USA"
)

sample_dif <- sample_dev |>
  dplyr::mutate(group = factor(ifelse(CNT %in% oecd_countries, "OECD", "NonOECD")))

mg_model <- mirt::multipleGroup(
  data = sample_dif |>
    dplyr::select(dplyr::all_of(dichotomous_clean)) |>
    as.data.frame(),
  model = 1,
  group = sample_dif$group,
  itemtype = "2PL",
  invariance = c("slopes", "intercepts", "free_means", "free_var"),
  verbose = TRUE
)

saveRDS(mg_model, file.path(processed_dir, "mg_model.rds"))

message("Running DIF test...")
dif_results <- mirt::DIF(
  mg_model,
  which.par = c("a1", "d"),
  scheme = "drop",
  verbose = TRUE
)

dif_df <- as.data.frame(dif_results)
dif_df$item <- rownames(dif_df)
dif_df <- dif_df |>
  dplyr::mutate(dif_flag = ifelse(adj_p < 0.05, "DIF", "No DIF"))

saveRDS(dif_df, file.path(processed_dir, "dif_results.rds"))
write.csv(dif_df, file.path(processed_dir, "dif_results.csv"), row.names = FALSE)

message("Cache build complete.")
