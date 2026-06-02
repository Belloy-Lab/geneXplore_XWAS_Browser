# Updating the Significance Threshold in geneXplore

geneXplore uses a suggestive significance threshold of **P < 1×10⁻⁵** for visualization, reflecting the reduced multiple testing burden of X-chromosome-only analyses. If you wish to change this threshold for your own instance, two components need to be updated: the **backend** (PheWeb2-API pipeline) and the **frontend** (Vue source files).

---

## 1. Backend — Peak-Calling Threshold

The backend controls which variants are flagged as peaks and labeled on the Manhattan/Miami plot. This is set at runtime via the `MANHATTAN_PEAK_PVAL_THRESHOLD` flag when running the manhattan step:

```bash
PYTHONPATH=/path/to/pheweb_override pheweb2 conf \
  HG_BUILD_NUMBER=38 \
  GENCODE_VERSION=47 \
  MANHATTAN_PEAK_PVAL_THRESHOLD=0.00001 \
  manhattan
```

Replace `0.00001` with your desired threshold. This must be rerun whenever the threshold changes, as it regenerates the manhattan output files.

---

## 2. Frontend — Display Threshold

The frontend controls the dashed significance line displayed on the Manhattan/Miami plot. These changes are made in the Vue source files and require a rebuild to take effect.

### Prerequisites

Node.js and npm must be installed. Build the frontend with:

```bash
cd /path/to/PheWeb2
npm run build
```

Copy the build output to your distribution directory:

```bash
cp -r /path/to/PheWeb2/dist/* /path/to/PheWeb2-dist/
```

---

### 2.1 ManhattanPlot.vue

Locate the significance threshold value in `src/components/ManhattanPlot.vue` and update it:

```python
filepath = "/path/to/PheWeb2/src/components/ManhattanPlot.vue"

with open(filepath, 'r') as f:
    content = f.read()

# Replace old threshold with new threshold
content = content.replace("1e-5", "1e-5")  # update both values to your desired threshold

with open(filepath, 'w') as f:
    f.write(content)

print("Done.")
```

---

### 2.2 MiamiPlot.vue

Apply the same change to `src/components/MiamiPlot.vue`:

```python
filepath = "/path/to/PheWeb2/src/components/MiamiPlot.vue"

with open(filepath, 'r') as f:
    content = f.read()

content = content.replace("1e-5", "1e-5")  # update both values to your desired threshold

with open(filepath, 'w') as f:
    f.write(content)

print("Done.")
```

---

### 2.3 Tooltip Display

The significance threshold value displayed in the plot tooltip is set separately. Locate the tooltip text in `ManhattanPlot.vue` and `MiamiPlot.vue` and update accordingly (e.g. `1E-5` → your desired value).

---

## 3. Rebuild and Verify

After making all frontend changes, rebuild the Vue source:

```bash
cd /path/to/PheWeb2
npm run build
cp -r /path/to/PheWeb2/dist/* /path/to/PheWeb2-dist/
```

Then restart the frontend server and verify the new threshold line appears correctly in the browser.

---

## Summary

| Component | File | Change |
|-----------|------|--------|
| Backend peak calling | pheweb2 runtime flag | `MANHATTAN_PEAK_PVAL_THRESHOLD=0.00001` |
| Manhattan plot display | `src/components/ManhattanPlot.vue` | Update threshold value |
| Miami plot display | `src/components/MiamiPlot.vue` | Update threshold value |
| Tooltip display | `ManhattanPlot.vue`, `MiamiPlot.vue` | Update tooltip text |