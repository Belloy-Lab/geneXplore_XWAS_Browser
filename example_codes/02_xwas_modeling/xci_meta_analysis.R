# =============================================================================
# X-Chromosome Association Study (XWAS) - Summary-Level Meta-Analysis
#                                         (eXCI and rXCI)
# =============================================================================
# This script meta-analyzes male and female X-chromosome summary statistics with
# GWAMA to produce eXCI or rXCI association results, for use when raw genotype
# data are unavailable. Set `model` below to choose which one to run.
#
#   - eXCI (escape from X-chromosome inactivation): random-effects
#     meta-analysis; males must be on the 0/1 dosage scale.
#   - rXCI (random X-chromosome inactivation): fixed-effect meta-analysis;
#     males must be on the 0/2 dosage scale.
#
# The male summary statistics are rescaled automatically to the scale the
# chosen model needs, based on the scale they arrive on (`male_input_scale`):
#
#     0/2 -> 0/1 : multiply male BETA and SE by 2
#     0/1 -> 0/2 : divide   male BETA and SE by 2
#     same scale : no change
#
# Males generated with PLINK2 --xchr-model 2 are on the 0/2 scale; with
# --xchr-model 1 they are on the 0/1 scale. Where original sex-combined rXCI
# results are available, they can be used directly instead of meta-analyzing.
#
# Requirements:
#   - GWAMA installed (https://genomics.ut.ee/en/tools/gwama)
#     or available via Docker: dmr07083/general-utility:1.0
#   - R packages: data.table, dplyr
#   - Female and male X-chromosome summary statistics, tab- or comma-delimited,
#     with columns:  MARKER, CHR, POS, EA, NEA, EAF, BETA, SE  (and N when
#     `quantitative` = TRUE).
#     MARKER must be identical for the same variant in both files. We use
#     CHR:POS:<alphabetically first allele>:<second allele>, so a variant with
#     swapped REF/ALT between sexes still merges; GWAMA aligns the effect allele.
#
# Output:
#   - GWAMA output (<output_name>.out) and its log
#   - A file formatted for PheWeb2-API ingestion with columns
#     CHROM, POS, REF, ALT, AF, BETA, SE, P, TEST
# =============================================================================

# -----------------------------------------------------------------------------
# Libraries
# -----------------------------------------------------------------------------

library(data.table)
library(dplyr)

# -----------------------------------------------------------------------------
# User-defined parameters - edit these before running
# -----------------------------------------------------------------------------

female_sumstats <- "/path/to/female/summary/stats.txt"
male_sumstats   <- "/path/to/male/summary/stats.txt"
out_dir         <- "/path/to/output/directory/"
output_name     <- "XWAS_meta"                  # prefix for output files
gwama_path      <- "/usr/bin/GWAMA"             # path to GWAMA executable

# Which model to run: "eXCI" or "rXCI"
model <- "eXCI"

# Scale of the incoming male summary statistics: "0/1" or "0/2"
male_input_scale <- "0/2"

# Set TRUE for quantitative (continuous) traits: adds GWAMA's --quantitative flag,
# which requires an N (sample size) column in both input files.
quantitative <- FALSE

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

stopifnot(model %in% c("eXCI", "rXCI"))
stopifnot(male_input_scale %in% c("0/1", "0/2"))

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

need_cols <- c("MARKER", "CHR", "POS", "EA", "NEA", "EAF", "BETA", "SE")
if (quantitative) need_cols <- c(need_cols, "N")

# Scale the males must be on for the chosen model, and the factor to get there
target_scale <- if (model == "eXCI") "0/1" else "0/2"
male_factor <- if (male_input_scale == target_scale) {
  1
} else if (male_input_scale == "0/2") {
  2      # 0/2 -> 0/1
} else {
  0.5    # 0/1 -> 0/2
}

# -----------------------------------------------------------------------------
# Read in summary statistics
# -----------------------------------------------------------------------------

cat("Reading female summary statistics...\n")
f <- fread(female_sumstats)

cat("Reading male summary statistics...\n")
m <- fread(male_sumstats)

for (nm in c("f", "m")) {
  miss <- setdiff(need_cols, names(get(nm)))
  if (length(miss)) {
    stop("Missing columns in ", ifelse(nm == "f", "female", "male"),
         " file: ", paste(miss, collapse = ", "))
  }
}

# -----------------------------------------------------------------------------
# Scale adjustment for males
# -----------------------------------------------------------------------------

if (male_factor == 1) {
  cat(sprintf("Males are already on the %s scale required for %s - no adjustment.\n",
              target_scale, model))
} else {
  cat(sprintf("Males are on the %s scale; %s needs %s - multiplying male BETA and SE by %g.\n",
              male_input_scale, model, target_scale, male_factor))
  m <- m %>% mutate(BETA = BETA * male_factor, SE = SE * male_factor)
}

# -----------------------------------------------------------------------------
# Write out individual summary stat files for GWAMA input
# -----------------------------------------------------------------------------

cat("Writing summary stat files for GWAMA...\n")
gwama_cols <- intersect(c("MARKER", "EA", "NEA", "EAF", "BETA", "SE", "N"), names(f))
female_file <- file.path(out_dir, "XWAS_female.txt")
male_file   <- file.path(out_dir, "XWAS_male.txt")
fwrite(select(f, all_of(gwama_cols)), female_file, sep = "\t", quote = FALSE)
fwrite(select(m, all_of(gwama_cols)), male_file,   sep = "\t", quote = FALSE)

# -----------------------------------------------------------------------------
# Create map file and GWAMA input file list
# -----------------------------------------------------------------------------

cat("Creating map file and file list...\n")
map <- bind_rows(select(f, CHR, MARKER, POS), select(m, CHR, MARKER, POS)) %>%
  distinct(MARKER, .keep_all = TRUE) %>%
  arrange(POS)

map_file  <- file.path(out_dir, "gwama.map.txt")
list_file <- file.path(out_dir, "gwama_list.txt")
fwrite(map, map_file, col.names = FALSE, sep = "\t")
writeLines(c(female_file, male_file), list_file)

# -----------------------------------------------------------------------------
# Run GWAMA
#   eXCI: random effects (--random)
#   rXCI: fixed effects (no --random)
#
# NOTE: Run this block in an interactive session or submit as a job.
# GWAMA is available via Docker: dmr07083/general-utility:1.0
# -----------------------------------------------------------------------------

out_prefix <- file.path(out_dir, output_name)

gwama_args <- c(
  "--map", map_file,
  "--name_marker", "MARKER",
  "--indel_alleles",
  if (quantitative) "--quantitative",
  if (model == "eXCI") "--random",
  "--filelist", list_file,
  "--output", out_prefix
)
gwama_cmd <- paste(c(gwama_path, gwama_args), collapse = " ")

cat("Running GWAMA (", model, ")...\n", sep = "")
cat("Command:", gwama_cmd, "\n")
status <- system(gwama_cmd)

gwama_out <- paste0(out_prefix, ".out")
if (status != 0 || !file.exists(gwama_out)) {
  stop("GWAMA did not produce ", gwama_out, " - check the GWAMA log.")
}

# -----------------------------------------------------------------------------
# Format GWAMA output for PheWeb2-API ingestion
#   - keep variants present in both the female and male files (N_studies == 2)
#   - GWAMA writes -9 for chromosome/position on its first row, so POS is
#     recovered from the marker name (CHR:POS:A:B)
#   - keep one row per position (smallest P)
# -----------------------------------------------------------------------------

gw_names <- c("CHR", "BP", "posID", "ALLELE1", "ALLELE0", "A1FREQ", "BETA", "SE",
              "BETA_95L", "BETA_95U", "Z", "P", "P_neg_log10", "Q_V", "Q_P", "i2",
              "N_studies", "N_incl", "META_DIR")

meta <- fread(gwama_out, data.table = FALSE)
if (ncol(meta) != length(gw_names)) {
  stop(sprintf("GWAMA output has %d columns, expected %d. Header: %s",
               ncol(meta), length(gw_names), paste(names(meta), collapse = " ")))
}
names(meta) <- gw_names
n_all <- nrow(meta)

res <- meta %>%
  filter(N_studies == 2) %>%
  mutate(POS_m = suppressWarnings(as.integer(sub("^[^:]+:([0-9]+):.*$", "\\1", posID)))) %>%
  filter(!is.na(POS_m), POS_m > 0, !is.na(BETA), !is.na(SE), !is.na(P), P >= 0, P <= 1) %>%
  transmute(CHROM = 23L, POS = POS_m, REF = ALLELE0, ALT = ALLELE1, AF = A1FREQ,
            BETA, SE, P, TEST = "ADD") %>%
  arrange(P) %>%
  distinct(POS, .keep_all = TRUE) %>%
  arrange(POS)

final_file <- file.path(out_dir, paste0(output_name, "_", model, "_XWAS.txt.gz"))
fwrite(res, final_file, sep = "\t", compress = "gzip")

cat(sprintf("%s meta-analysis complete: %d GWAMA rows -> %d variants written to %s\n",
            model, n_all, nrow(res), final_file))
