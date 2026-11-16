# 01_preprocessing

Prepares X-chromosome summary statistics for ingestion into geneXplore. Run the steps in order; steps 2 to 4 are needed only where they apply to your data.

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `01_liftover_format.R` | Optional hg19 to hg38 liftover (UCSC liftOver), then renames columns to the final format. Edit its column-mapping block to match your dataset. |
| 2 | `02_remove_par.R` | Removes pseudoautosomal (PAR) variants; keeps GRCh38 X:2,781,480-155,701,382. |
| 3 | `03_flip_ref_alt.py` | Orients REF/ALT to the dbSNP v157 hg38 reference; where alleles are swapped, flips the BETA sign and sets AF to 1 - AF. |
| 4 | `04_harmonize_male_coding.R` | Converts male statistics coded 0/1 to 0/2 by halving BETA and SE. Only for files verified as 0/1. |

**Final format:** gzip-compressed, tab-delimited, with columns `CHROM` (23), `POS` (GRCh38), `REF`, `ALT`, `AF`, `BETA`, `SE`, `P`, `TEST` (`ADD`).

The R scripts are configured by editing the parameters at the top of each file. The Python script takes command-line arguments (`--help`).

Next: XCI modeling and meta-analysis in `../02_xwas_modeling/`.
