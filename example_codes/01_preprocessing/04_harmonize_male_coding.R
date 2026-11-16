# =============================================================================
# Step 4 - Harmonize male genotype coding to 0/2
# =============================================================================
# On the X chromosome, males are hemizygous. geneXplore uses the 0/2 coding for
# males (the rXCI convention, PLINK --xchr-model 2). A study that coded males
# 0/1 reports an effect per unit of a dosage that is half as large, so its
# estimates are converted to the 0/2 scale by halving BETA and SE:
#
#     BETA(0/2) = BETA(0/1) / 2        SE(0/2) = SE(0/1) / 2
#
# P-values and allele frequencies are unchanged. Only files whose male coding
# was verified as 0/1 from the publication or repository should be listed
# below. In geneXplore this applied to the male-stratified restless legs
# syndrome results (Schormair et al. 2024, Nat Genet).
#
# Input : gzip-compressed, tab- or comma-delimited files with BETA and SE
#         columns (names configurable).
# Output: converted copies written to output_dir (inputs are never modified).
#
# Requirements: R packages data.table and R.utils (R.utils lets fread read .gz)
# =============================================================================

library(data.table)

# -----------------------------------------------------------------------------
# User-defined parameters - edit these before running
# -----------------------------------------------------------------------------

# Male-stratified files that were coded 0/1
input_files <- c(
  "/path/to/RLS_male_XWAS.txt.gz"
)

output_dir <- "/path/to/output/male_0_2/"       # must differ from the input folder

col_beta <- "BETA"
col_se   <- "SE"

# -----------------------------------------------------------------------------
# Convert each file
# -----------------------------------------------------------------------------

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

for (src in input_files) {

  dst <- file.path(output_dir, basename(src))
  if (normalizePath(src) == normalizePath(dst, mustWork = FALSE)) {
    stop("output_dir must not contain the input file: ", src)
  }

  header_line <- readLines(gzfile(src), n = 1)
  sep <- if (grepl("\t", header_line, fixed = TRUE)) "\t" else ","

  df <- fread(src, sep = sep, header = TRUE)
  if (!all(c(col_beta, col_se) %in% names(df))) {
    stop("Columns ", col_beta, " and/or ", col_se, " not found in ", basename(src))
  }

  df[[col_beta]] <- df[[col_beta]] / 2
  df[[col_se]]   <- df[[col_se]] / 2

  fwrite(df, dst, sep = sep, compress = "gzip", na = "NA", quote = FALSE)
  cat(sprintf("%s: %d rows converted (BETA and SE halved)\n", basename(src), nrow(df)))
}
