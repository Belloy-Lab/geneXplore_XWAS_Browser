# =============================================================================
# X-Chromosome Association Study (XWAS) — Genotype-Based Modeling
# =============================================================================
# This script runs PLINK2-based X-chromosome association analyses under four
# modeling strategies:
#   - eXCI  : escape from X-chromosome inactivation (xchr-model 1, with sex covariate)
#   - rXCI  : random X-chromosome inactivation (xchr-model 2, with sex covariate)
#   - female: female-only analysis (xchr-model 2, no sex covariate)
#   - male  : male-only analysis (xchr-model 1, no sex covariate)
#
# Requirements:
#   - PLINK2 installed and accessible in PATH
#   - PLINK binary format genotype files (.bed/.bim/.fam)
#   - Phenotype file in PLINK2 format
#   - Covariate file in PLINK2 format
#   - Sample ID files for filtering (e.g. female-only, male-only subsets)
#
# Output:
#   - PLINK2 .glm.logistic or .glm.linear files per phenotype per model
# =============================================================================

# -----------------------------------------------------------------------------
# User-defined parameters — edit these before running
# -----------------------------------------------------------------------------

bfile_directory   <- "/path/to/genotype/plink_bfile"   # PLINK binary file prefix
covariate_file    <- "/path/to/covariates.txt"          # Covariate file
covariate_names   <- "PC1,PC2,PC3,PC4,PC5,PC6,PC7,PC8,PC9,PC10,age"  # Covariate names
phenotype_file    <- "/path/to/phenotypes.txt"          # Phenotype file

# Sample ID files for sex-stratified analyses
valid_sample_id_file_all    <- "/path/to/all_samples.txt"     # All samples (eXCI, rXCI)
valid_sample_id_file_female <- "/path/to/female_samples.txt"  # Female samples only
valid_sample_id_file_male   <- "/path/to/male_samples.txt"    # Male samples only

output_dir <- "/path/to/output/"  # Output directory
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# eXCI — escape from X-chromosome inactivation
# xchr-model 1: males coded 0/2 (like females), sex included as covariate
# -----------------------------------------------------------------------------

cmd_eXCI <- paste(
  "plink2",
  paste0("--bfile ", bfile_directory),
  paste0("--keep ", valid_sample_id_file_all),
  paste0("--covar ", covariate_file),
  paste0("--covar-name ", covariate_names),
  "--covar-variance-standardize",
  "--chr X",
  "--xchr-model 1",
  "--glm sex hide-covar omit-ref log10",
  paste0("--pheno ", phenotype_file),
  paste0("--out ", file.path(output_dir, "eXCI"))
)

cat("Running eXCI model...\n")
system(cmd_eXCI)

# -----------------------------------------------------------------------------
# rXCI — random X-chromosome inactivation
# xchr-model 2: males coded 0/1, sex included as covariate
# -----------------------------------------------------------------------------

cmd_rXCI <- paste(
  "plink2",
  paste0("--bfile ", bfile_directory),
  paste0("--keep ", valid_sample_id_file_all),
  paste0("--covar ", covariate_file),
  paste0("--covar-name ", covariate_names),
  "--covar-variance-standardize",
  "--chr X",
  "--xchr-model 2",
  "--glm sex hide-covar omit-ref log10",
  paste0("--pheno ", phenotype_file),
  paste0("--out ", file.path(output_dir, "rXCI"))
)

cat("Running rXCI model...\n")
system(cmd_rXCI)

# -----------------------------------------------------------------------------
# Female-only analysis
# xchr-model 2: females only, no sex covariate
# -----------------------------------------------------------------------------

cmd_female <- paste(
  "plink2",
  paste0("--bfile ", bfile_directory),
  paste0("--keep ", valid_sample_id_file_female),
  paste0("--covar ", covariate_file),
  paste0("--covar-name ", covariate_names),
  "--covar-variance-standardize",
  "--chr X",
  "--xchr-model 2",
  "--glm hide-covar omit-ref log10",
  paste0("--pheno ", phenotype_file),
  paste0("--out ", file.path(output_dir, "female"))
)

cat("Running female-only model...\n")
system(cmd_female)

# -----------------------------------------------------------------------------
# Male-only analysis
# xchr-model 1: males only, no sex covariate
# -----------------------------------------------------------------------------

cmd_male <- paste(
  "plink2",
  paste0("--bfile ", bfile_directory),
  paste0("--keep ", valid_sample_id_file_male),
  paste0("--covar ", covariate_file),
  paste0("--covar-name ", covariate_names),
  "--covar-variance-standardize",
  "--chr X",
  "--xchr-model 1",
  "--glm hide-covar omit-ref log10",
  paste0("--pheno ", phenotype_file),
  paste0("--out ", file.path(output_dir, "male"))
)

cat("Running male-only model...\n")
system(cmd_male)

cat("All models complete. Output written to:", output_dir, "\n")