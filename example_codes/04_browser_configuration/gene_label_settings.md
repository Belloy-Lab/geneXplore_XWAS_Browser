# Gene label settings

geneXplore labels the most significant variants with gene names on the Manhattan and Miami plots. PheWeb2's defaults are tuned for genome-wide plots; because geneXplore shows only the X chromosome, labels are denser and an overlap check keeps them readable.

## Current rules

| Setting | Value |
|---------|-------|
| Label threshold | Variants with P < 1e-5 |
| Maximum labels per plot | 12 |
| Minimum distance between labelled variants | 1 Mb |
| Overlap suppression | A label is skipped if it would overlap a label of a more significant neighbouring variant |

**Overlap test.** For each candidate label, the width is estimated as 3.5 px per character of the gene name plus 3 px. The label is skipped if it overlaps an already placed label horizontally and sits less than 16 px away vertically. On Miami plots the test is applied separately to the top and bottom halves.

## Where it is implemented

In the frontend components `ManhattanPlot.vue` and `MiamiPlot.vue` (PheWeb2 `src/`). No backend change or API restart is involved.

To change a rule, edit the label-selection block in both files, rebuild the frontend (`npm run build`) and redeploy the built files.

## Keeping thresholds consistent

The label threshold (P < 1e-5) matches the suggestive significance threshold used for plotting and for backend peak calling. If you change one, change all of them; see `update_significance_threshold.md`.
