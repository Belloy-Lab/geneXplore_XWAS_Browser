#!/usr/bin/env python3
"""
Step 3 - Align REF/ALT alleles to the dbSNP v157 (GRCh38) reference.

For every summary statistic file, each variant is compared with the reference
allele at the same X-chromosome position:

  * REF/ALT match the reference         -> kept as is
  * REF/ALT are swapped relative to it  -> REF and ALT are exchanged, BETA is
                                           negated and AF is set to 1 - AF
  * position absent from the reference,
    or alleles match neither way        -> left unchanged (counted as "skipped")

Files are modified IN PLACE. A backup copy (<file>.bak) is written first and
restored automatically if a file fails. Output is tab-delimited (comma-delimited
input is detected and rewritten as tab-delimited).

Input files: gzip-compressed, tab- or comma-delimited, with header columns
POS, REF, ALT, AF and BETA, in GRCh38.

Reference file: tab-delimited dbSNP v157 GRCh38 table. Columns used (0-based):
0 = chromosome ("X"), 1 = position, 3 = reference allele, 4 = alternate
allele(s), comma-separated.

Example:
    python3 03_flip_ref_alt.py --data-dir /path/to/stats \
        --ref-file /path/to/rsids-v157-hg38.tsv.gz --exclude-dirs single_cell
"""
import argparse
import gzip
import os
import shutil
import sys
import time
from pathlib import Path


def load_reference(ref_file):
    print("Loading X chromosome reference variants...", flush=True)
    ref = {}
    with gzip.open(ref_file, "rt") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) < 5:
                continue
            if parts[0] != "X":
                continue
            pos, ref_allele, alt_alleles = parts[1], parts[3], parts[4]
            ref[pos] = (ref_allele, set(alt_alleles.split(",")))
    print(f"Loaded {len(ref):,} X chromosome reference variants", flush=True)
    return ref


def harmonize_file(filepath, ref):
    with gzip.open(filepath, "rt") as f:
        first_line = f.readline()
    delim = "," if "," in first_line else "\t"
    backup = str(filepath) + ".bak"
    shutil.copy2(filepath, backup)
    tmp = str(filepath) + ".tmp.gz"
    flipped = kept = skipped = 0
    try:
        with gzip.open(filepath, "rt") as fin, gzip.open(tmp, "wt") as fout:
            header = fin.readline().strip().split(delim)
            pos_idx = header.index("POS")
            ref_idx = header.index("REF")
            alt_idx = header.index("ALT")
            af_idx = header.index("AF")
            beta_idx = header.index("BETA")
            fout.write("\t".join(header) + "\n")
            for line in fin:
                parts = line.strip().split(delim)
                if len(parts) <= max(pos_idx, ref_idx, alt_idx, af_idx, beta_idx):
                    continue
                pos = parts[pos_idx]
                file_ref = parts[ref_idx]
                file_alt = parts[alt_idx]
                if pos in ref:
                    ref_ref, ref_alts = ref[pos]
                    if file_ref == ref_ref and file_alt in ref_alts:
                        kept += 1
                    elif file_alt == ref_ref and file_ref in ref_alts:
                        parts[ref_idx], parts[alt_idx] = parts[alt_idx], parts[ref_idx]
                        parts[beta_idx] = str(-float(parts[beta_idx]))
                        parts[af_idx] = str(1 - float(parts[af_idx]))
                        flipped += 1
                    else:
                        skipped += 1
                else:
                    skipped += 1
                fout.write("\t".join(parts) + "\n")
        os.replace(tmp, filepath)
        print(f"  Done: {Path(filepath).name} - kept={kept:,} flipped={flipped:,} skipped={skipped:,}",
              flush=True)
    except Exception as e:
        shutil.copy2(backup, filepath)
        if os.path.exists(tmp):
            os.remove(tmp)
        print(f"  ERROR: {filepath}: {e}", flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", required=True, help="folder searched recursively for summary statistic files")
    ap.add_argument("--ref-file", required=True, help="dbSNP v157 GRCh38 reference table (.tsv.gz)")
    ap.add_argument("--pattern", default="*.txt.gz", help="file name pattern (default: *.txt.gz)")
    ap.add_argument("--exclude-dirs", nargs="*", default=[],
                    help="folder names to skip (e.g. data that were already aligned)")
    args = ap.parse_args()

    data_dir = Path(args.data_dir)
    files = [
        f for f in sorted(data_dir.rglob(args.pattern))
        if not any(part in args.exclude_dirs for part in f.parts)
        and not str(f).endswith(".bak")
        and not f.name.startswith("._")
    ]
    if not files:
        sys.exit("No files found.")
    print(f"Found {len(files)} files to harmonize\n", flush=True)

    ref = load_reference(args.ref_file)
    print()
    start = time.time()
    for filepath in files:
        print(f"Harmonizing: {filepath.relative_to(data_dir)}", flush=True)
        harmonize_file(filepath, ref)
    print(f"\nAll done! Total time: {(time.time() - start) / 60:.1f} minutes", flush=True)


if __name__ == "__main__":
    main()
