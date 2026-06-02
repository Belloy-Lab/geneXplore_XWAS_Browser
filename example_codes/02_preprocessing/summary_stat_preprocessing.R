# =============================================================================
# X-Chromosome Summary Statistics — Liftover (hg19 → hg38) and Preprocessing
# =============================================================================
# This script performs two steps:
#   1. Optionally lifts over X-chromosome summary statistics from hg19 to hg38
#      using the UCSC liftOver tool (skip if data is already in hg38)
#   2. Preprocesses and formats the summary statistics for ingestion
#      into the PheWeb2-API pipeline
#
# Requirements:
#   - UCSC liftOver executable (https://hgdownload.soe.ucsc.edu/admin/exe/)
#     (only required if already_hg38 = FALSE)
#   - hg19ToHg38.over.chain.gz chain file
#     (http://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/)
#     (only required if already_hg38 = FALSE)
#   - R packages: data.table, tidyverse, Rfast
#
# Output:
#   - Gzip-compressed, tab-delimited summary statistic files formatted for
#     PheWeb2-API ingestion with columns:
#     CHROM, POS, REF, ALT, AF, BETA, SE, P, TEST
# =============================================================================

# -----------------------------------------------------------------------------
# Libraries
# -----------------------------------------------------------------------------

library(data.table)
library(tidyverse)
library(Rfast)

# -----------------------------------------------------------------------------
# User-defined parameters — edit these before running
# -----------------------------------------------------------------------------

# Directory containing input summary statistic files (.gz)
input_dir <- "/path/to/input/summary/stats/"

# Directory for liftover intermediate files (only used if already_hg38 = FALSE)
liftover_dir <- "/path/to/liftover/output/"

# Directory for final preprocessed output files
output_dir <- "/path/to/final/output/"

# Are your summary statistics already in GRCh38 (hg38)?
# Set to TRUE to skip liftover and proceed directly to preprocessing
already_hg38 <- FALSE

# Liftover reference files (only required if already_hg38 = FALSE)
ref_dir    <- "/path/to/liftover/reference/"
chain_file <- "hg19ToHg38.over.chain.gz"

# Input column name mapping — adjust to match your dataset's column names
col_pos  <- "POS_b37"       # base pair position column (hg19 if lifting over, hg38 if already lifted)
col_ref  <- "REF"           # reference allele column
col_alt  <- "ALT"           # alternative allele column
col_af   <- "ALT_AF" # ALT allele frequency column
col_beta <- "EFFECT_SIZE"   # effect size (BETA) column
col_se   <- "SE"            # standard error column
col_pval <- "pvalue"        # p-value column

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
if (!already_hg38) {
  dir.create(liftover_dir, showWarnings = FALSE, recursive = TRUE)
}

input_files  <- list.files(input_dir, pattern = ".gz$", full.names = TRUE)
liftover_exe <- paste0(ref_dir, "liftOver")
chain_path   <- paste0(ref_dir, chain_file)

# -----------------------------------------------------------------------------
# Process each file
# -----------------------------------------------------------------------------

for (file in input_files) {
  
  name_dset <- tools::file_path_sans_ext(basename(file))
  cat(paste0("Starting to process dataset: ", name_dset, "\n"))
  
  # ---------------------------------------------------------------------------
  # Step 1: Load dataset
  # ---------------------------------------------------------------------------
  
  df <- fread(file, header = TRUE)
  
  # ---------------------------------------------------------------------------
  # Step 2: Liftover hg19 → hg38 (skipped if already_hg38 = TRUE)
  # ---------------------------------------------------------------------------
  
  if (!already_hg38) {
    
    cat("  Performing liftover hg19 → hg38...\n")
    
    df2 <- df %>%
      mutate(
        CHR      = "X",
        posID_19 = paste(CHR, .data[[col_pos]], sep = ":"),
        SNP_19   = paste(CHR, .data[[col_pos]], .data[[col_ref]], .data[[col_alt]], sep = ":")
      ) %>%
      arrange(CHR, .data[[col_pos]])
    
    # Create BED file
    df2_bed <- df2[, c("CHR", col_pos, col_pos, "SNP_19")]
    setnames(df2_bed, 1:4, c("CHR", "START", "END", "NAME"))
    df2_bed <- df2_bed %>%
      mutate(
        CHR   = paste0("chr", CHR),
        START = as.integer(START),
        END   = as.integer(END) + 1
      )
    
    bed_file <- paste0(liftover_dir, name_dset, "_XWAS_hg19_to_lift.txt")
    fwrite(df2_bed, bed_file, col.names = FALSE, row.names = FALSE, quote = FALSE, sep = "\t")
    
    # Run liftOver
    lifted     <- paste0(liftover_dir, name_dset, "_XWAS_hg38_lifted.txt")
    not_lifted <- paste0(liftover_dir, name_dset, "_XWAS_hg38_not_lifted.txt")
    cmd <- paste(liftover_exe, bed_file, chain_path, lifted, not_lifted, sep = " ")
    system(cmd)
    
    # Merge lifted coordinates back
    bedl <- fread(lifted, sep = "\t", header = FALSE)
    setnames(bedl, 1:4, c("CHRl", "START", "END", "SNP_19"))
    df2_lifted <- inner_join(df2, bedl[, c("SNP_19", "START", "CHRl")], by = "SNP_19")
    
    # Use lifted POS
    df2_lifted <- df2_lifted %>% rename(POS = START)
    
  } else {
    
    cat("  Data already in hg38 — skipping liftover.\n")
    
    # Standardize position column name to POS for downstream steps
    df2_lifted <- df %>%
      mutate(CHR = "X") %>%
      rename(POS = all_of(col_pos))
    
  }
  
  # ---------------------------------------------------------------------------
  # Step 3: Preprocess and format for PheWeb2-API ingestion
  # ---------------------------------------------------------------------------
  
  df3 <- df2_lifted %>%
    rename(
      AF   = all_of(col_af),
      BETA = all_of(col_beta),
      P    = all_of(col_pval)
    ) %>%
    mutate(
      CHROM = 23,       # X chromosome coded as 23 for PheWeb2-API ingestion
      TEST  = "ADD",
      P     = as.numeric(P)
    ) %>%
    filter(P <= 1) %>%
    dplyr::select(CHROM, POS, REF, ALT, AF, BETA, SE, P, TEST) %>%
    arrange(CHROM, POS)
  
  # ---------------------------------------------------------------------------
  # Step 4: Quality checks - Make sure there are no missing values and that the ranges look reasonable (POS < 160,000,000)
  # ---------------------------------------------------------------------------
  
  cat(paste0("  Total variants: ",    nrow(df3), "\n"))
  cat(paste0("  Unique positions: ",  n_distinct(df3$POS), "\n"))
  cat(paste0("  POS range: ",         min(df3$POS), " - ", max(df3$POS), "\n"))
  cat(paste0("  P range: ",           min(df3$P),   " - ", max(df3$P),   "\n"))
  
  # ---------------------------------------------------------------------------
  # Step 5: Write output
  # ---------------------------------------------------------------------------
  
  out_file <- paste0(output_dir, name_dset, "_XWAS.txt.gz")
  fwrite(df3, out_file, sep = "\t", col.names = TRUE)
  
  cat(paste0("Finished processing dataset: ", name_dset, "\n\n"))
  
}

cat("All datasets processed.\n")