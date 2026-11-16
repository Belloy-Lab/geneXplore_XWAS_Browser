# =============================================================================
# Step 2 - Remove pseudoautosomal region (PAR) variants
# =============================================================================
# geneXplore keeps only the non-PAR portion of the X chromosome so that all
# summary statistics are consistent across datasets. In GRCh38 the non-PAR
# region is X:2,781,480-155,701,382 (inclusive). Variants outside this interval
# (PAR1 and PAR2) are removed from every dataset that contained them.
#
# Input : gzip-compressed, tab- or comma-delimited summary statistics with a
#         header row and a position column (POS, BP or similar), in GRCh38.
# Output: copies of the files with PAR rows removed, written to output_dir with
#         the same relative paths (input files are never modified), plus a CSV
#         log with columns: dir, file, n_before, n_removed, n_after
#
# Requirements: R packages data.table and R.utils (R.utils lets fread read .gz)
# =============================================================================

library(data.table)

# -----------------------------------------------------------------------------
# User-defined parameters - edit these before running
# -----------------------------------------------------------------------------

input_dir  <- "/path/to/input/summary/stats/"
output_dir <- "/path/to/output/nonPAR/"          # must differ from input_dir
log_file   <- "par_removal_log.csv"

# GRCh38 non-PAR boundaries of the X chromosome (inclusive)
nonpar_start <- 2781480
nonpar_end   <- 155701382

# Names the position column may have
pos_candidates <- c("POS", "BP", "BASE_PAIR_LOCATION", "POSITION", "pos", "bp")

# -----------------------------------------------------------------------------
# Process each file
# -----------------------------------------------------------------------------

if (normalizePath(input_dir) == normalizePath(output_dir, mustWork = FALSE)) {
  stop("output_dir must differ from input_dir (inputs are never overwritten)")
}

files <- list.files(input_dir, pattern = "\\.gz$", recursive = TRUE)
files <- files[!grepl("(^|/)\\._", files)]      # skip macOS resource-fork files

log_rows <- vector("list", length(files))

for (i in seq_along(files)) {

  f   <- files[i]
  src <- file.path(input_dir, f)
  dst <- file.path(output_dir, f)

  # Keep the input's delimiter (tab or comma)
  header_line <- readLines(gzfile(src), n = 1)
  sep <- if (grepl("\t", header_line, fixed = TRUE)) "\t" else ","

  df <- fread(src, sep = sep, header = TRUE)

  pos_col <- intersect(pos_candidates, names(df))[1]
  if (is.na(pos_col)) {
    warning("No position column in ", f, " - skipped")
    next
  }

  n_before <- nrow(df)
  keep     <- df[[pos_col]] >= nonpar_start & df[[pos_col]] <= nonpar_end
  df       <- df[which(keep)]
  n_after  <- nrow(df)

  dir.create(dirname(dst), showWarnings = FALSE, recursive = TRUE)
  fwrite(df, dst, sep = sep, compress = "gzip", na = "NA", quote = FALSE)

  log_rows[[i]] <- data.table(
    dir       = dirname(f),
    file      = basename(f),
    n_before  = n_before,
    n_removed = n_before - n_after,
    n_after   = n_after
  )
  cat(sprintf("%s: removed %d of %d\n", f, n_before - n_after, n_before))
}

fwrite(rbindlist(log_rows), log_file)
cat("Done. Log written to", log_file, "\n")
