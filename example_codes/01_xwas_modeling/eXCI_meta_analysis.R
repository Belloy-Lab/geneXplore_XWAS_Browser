# =============================================================================
# eXCI X-Chromosome Association Study — Summary-Level Meta-Analysis
# =============================================================================
# This script performs a random effects meta-analysis of male and female
# X-chromosome summary statistics to produce eXCI association results,
# for use when raw genotype data is unavailable.
#
# eXCI (escape from X-chromosome inactivation) requires males to be on the
# 0/1 dosage scale before meta-analysis. The required adjustment depends on
# the scale of the incoming male summary statistics:
#
#   - Males on 0/1 scale: no adjustment needed
#   - Males on 0/2 scale: multiply BETA and SE by 2 before meta-analysis
#
# NOTE: rXCI meta-analysis (requiring males on 0/2 scale) is not demonstrated
# here. If your male summary statistics were generated using PLINK2
# --xchr-model 2, they are already on the 0/2 scale and can be used directly
# for rXCI without meta-analysis.
#
# Requirements:
#   - GWAMA installed (https://genomics.ut.ee/en/tools/gwama)
#     or available via Docker: dmr07083/general-utility:1.0
#   - R packages: data.table, tidyverse
#   - Female and male X-chromosome summary statistics
#     in GWAMA-compatible format (.gen090)
#
# Output:
#   - GWAMA meta-analysis output files for eXCI
# =============================================================================

# -----------------------------------------------------------------------------
# Libraries
# -----------------------------------------------------------------------------

library(data.table)
library(tidyverse)

# -----------------------------------------------------------------------------
# User-defined parameters — edit these before running
# -----------------------------------------------------------------------------

female_sumstats <- "/path/to/clean/female/summary/stats.gen090"
male_sumstats   <- "/path/to/clean/male/summary/stats.gen090"
out_dir         <- "/path/to/output/directory/"
output_name     <- "eXCI_XWAS"   # prefix for GWAMA output files
gwama_path      <- "/usr/bin/GWAMA"  # path to GWAMA executable

# Is your male input on the 0/1 or 0/2 scale?
# Set to TRUE if males are on 0/2 scale and need to be converted to 0/1
male_on_0_2_scale <- TRUE

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
setwd(out_dir)

# -----------------------------------------------------------------------------
# Read in summary statistics
# -----------------------------------------------------------------------------

cat("Reading female summary statistics...\n")
f <- fread(female_sumstats)

cat("Reading male summary statistics...\n")
m <- fread(male_sumstats)

# -----------------------------------------------------------------------------
# Scale adjustment for males
# eXCI requires males on 0/1 scale
# If males are on 0/2 scale, multiply BETA and SE by 2
# -----------------------------------------------------------------------------

if (male_on_0_2_scale) {
  cat("Males are on 0/2 scale — multiplying BETA and SE by 2 to convert to 0/1 scale...\n")
  m <- m %>%
    mutate(BETA = 2 * BETA,
           SE   = 2 * SE)
} else {
  cat("Males are on 0/1 scale — no adjustment needed.\n")
}

# -----------------------------------------------------------------------------
# Write out individual summary stat files for GWAMA input
# -----------------------------------------------------------------------------

cat("Writing summary stat files for GWAMA...\n")
fwrite(f, paste0(out_dir, "XWAS_female.txt"), col.names = TRUE, row.names = FALSE, quote = FALSE, sep = "\t")
fwrite(m, paste0(out_dir, "XWAS_male.txt"),   col.names = TRUE, row.names = FALSE, quote = FALSE, sep = "\t")

# -----------------------------------------------------------------------------
# Create map and key files
# -----------------------------------------------------------------------------

cat("Creating map and key files...\n")
map <- rbind(f, m) %>%
  distinct(MARKER, .keep_all = TRUE) %>%
  arrange(CHR, POS)

key <- map %>% dplyr::select(MARKER, SNP)
map <- map %>% dplyr::select(CHR, MARKER, POS)

mapn <- paste0(out_dir, "gwama.map.txt")
keyn <- paste0(out_dir, "gwama.key.txt")

fwrite(map, mapn, col.names = FALSE, sep = "\t")
fwrite(key, keyn, col.names = TRUE,  sep = "\t")

# -----------------------------------------------------------------------------
# Create GWAMA input file list
# -----------------------------------------------------------------------------

cat("Creating GWAMA file list...\n")
gwama_list <- as.data.frame(c(
  paste0(out_dir, "XWAS_female.txt"),
  paste0(out_dir, "XWAS_male.txt")
))
names(gwama_list) <- NULL

gwamaf <- paste0(out_dir, "gwama_list.txt")
fwrite(gwama_list, gwamaf, col.names = FALSE, row.names = FALSE, quote = FALSE, sep = "\t")

# -----------------------------------------------------------------------------
# Run GWAMA
# Random effects meta-analysis (--random) for eXCI
#
# NOTE: Run this block in an interactive session or submit as a job.
# GWAMA is available via Docker: dmr07083/general-utility:1.0
# -----------------------------------------------------------------------------

gwama_cmd <- paste(
  gwama_path,
  paste0("--map ", mapn),
  "--name_marker MARKER",
  "--indel_alleles",
  "--random",
  paste0("--filelist ", gwamaf),
  paste0("--output ", out_dir, output_name)
)

cat("Running GWAMA...\n")
cat("Command:", gwama_cmd, "\n")
system(gwama_cmd)

cat("eXCI meta-analysis complete. Output written to:", out_dir, "\n")