#!/usr/bin/env python3
"""Print pipeline step checklist as JSON systemMessage for Claude Code Stop hook."""
import json
import os
import re
import sys
import glob
from pathlib import Path

try:
    import yaml
    import pandas as pd
except ImportError:
    sys.exit(0)

CONFIG = Path("config/config.yaml")
if not CONFIG.exists():
    sys.exit(0)

try:
    config = yaml.safe_load(CONFIG.read_text())
except Exception:
    sys.exit(0)

run_id  = config.get("run_id", "")
out_dir = config.get("output_dir", "results")
base    = Path(out_dir) / run_id

if not base.exists():
    sys.exit(0)

try:
    df = pd.read_csv(config.get("samples", "config/samples.tsv"),
                     sep="\t", comment="#", header=None, names=["s","r1","r2"])
    samples = df["s"].tolist()
except Exception:
    sys.exit(0)

PER = [
    ("01_spades",           "SPAdes           "),
    ("02_mothur_assemble",  "make.contigs     "),
    ("03_mothur_qc",        "trim.seqs        "),
    ("04_mothur_derep1",    "unique.seqs 1    "),
    ("05_mothur_align",     "align.seqs       "),
    ("06_mothur_screen",    "screen.seqs      "),
    ("07_mothur_filter",    "filter.seqs      "),
    ("08_mothur_derep2",    "unique.seqs 2    "),
    ("09_mothur_listseqs",  "list.seqs        "),
    ("10_iped",             "IPED             "),
]

CROSS = [
    ("11_merge",               "merge"),
    ("12_mothur_unique_all",   "unique all"),
    ("13_chimera_uchime",      "chimera.uchime"),
    ("14_chimera_slayer",      "chimera.slayer"),
    ("15_chimera_perseus",     "chimera.perseus"),
    ("16_catch",               "CATCh"),
    ("17_mothur_remove",       "remove.seqs"),
    ("18_mothur_split",        "split.groups"),
    ("19_uparse_format",       "uparse format"),
    ("20_merge_uparse",        "merge uparse"),
    ("21_uparse_sortbysize",   "sortbysize"),
    ("22_uparse_cluster",      "cluster_otus"),
    ("23_uparse_map",          "usearch_global"),
]

FINAL = ["OCTOPUS_OTUs.fasta", "OCTOPUS.shared", "OCTOPUS.biom", "OCTOPUS_otutab_txt"]

lines = [f"Pipeline: {run_id}  |  output: {base}", ""]

# Per-sample table
col_w = max(len(s) for s in samples) + 2
hdr = "Step             | " + " | ".join(f"{s:<{col_w}}" for s in samples)
sep = "-" * 17 + "|" + (("-" * (col_w + 2) + "|") * len(samples))
lines += [hdr, sep]
for step_dir, label in PER:
    icons = ["✅" if (base / "per_sample" / s / step_dir).exists() else "⏳" for s in samples]
    lines.append(f"{label}| " + " | ".join(f"{ic:<{col_w}}" for ic in icons))

lines += ["", "Cross-sample:"]
for step_dir, label in CROSS:
    icon = "✅" if (base / "cross_sample" / step_dir).exists() else "⏳"
    lines.append(f"  {icon} {label}")

lines += ["", "Final outputs:"]
for fname in FINAL:
    icon = "✅" if (base / "final" / fname).exists() else "⏳"
    lines.append(f"  {icon} {fname}")

# Progress from most-recent log
logs = sorted(glob.glob("results/*_run.log"), key=os.path.getmtime, reverse=True)
if logs:
    try:
        content = Path(logs[0]).read_text()
        matches = re.findall(r"\d+ of \d+ steps \(\d+%\) done", content)
        if matches:
            lines += ["", f"Progress: {matches[-1]}  (log: {logs[0]})"]
        elif "WorkflowError" in content or "Error in rule" in content:
            lines += ["", "Status: ERROR — check log for details"]
        elif "100%) done" in content:
            lines += ["", "Status: COMPLETE ✅"]
    except Exception:
        pass

print(json.dumps({"systemMessage": "\n".join(lines)}))
