configfile: "config/config.yaml"

import sys
import pandas as pd
from pathlib import Path

# Load samples table
try:
    samples_df = pd.read_csv(
        config["samples"], sep="\t", header=None,
        names=["sample", "r1", "r2"], comment="#"
    )
except FileNotFoundError:
    raise SystemExit(f"[OCToPUS] Samples file not found: {config['samples']}\n  → Check 'samples:' in config/config.yaml")
except Exception as e:
    raise SystemExit(f"[OCToPUS] Failed to parse samples file {config['samples']}: {e}")
SAMPLES = samples_df["sample"].tolist()
RUN = config["run_id"]

TOOLS_DIR = "workflow/scripts/external"
MOTHUR_BIN = f"{TOOLS_DIR}/bin/mothur"

# Per-sample rules
include: "workflow/rules/per_sample/01_spades.smk"
include: "workflow/rules/per_sample/02_mothur_assemble.smk"
include: "workflow/rules/per_sample/03_mothur_qc.smk"
include: "workflow/rules/per_sample/04_mothur_derep1.smk"
include: "workflow/rules/per_sample/05_mothur_align.smk"
include: "workflow/rules/per_sample/06_mothur_screen.smk"
include: "workflow/rules/per_sample/07_mothur_filter.smk"
include: "workflow/rules/per_sample/08_mothur_derep2.smk"
include: "workflow/rules/per_sample/09_mothur_listseqs.smk"
include: "workflow/rules/per_sample/10_iped.smk"

# Cross-sample rules
include: "workflow/rules/cross_sample/11_merge.smk"
include: "workflow/rules/cross_sample/12_mothur_unique_all.smk"
include: "workflow/rules/cross_sample/13_chimera_uchime.smk"
include: "workflow/rules/cross_sample/14_chimera_slayer.smk"
include: "workflow/rules/cross_sample/15_chimera_perseus.smk"
include: "workflow/rules/cross_sample/16_catch.smk"
include: "workflow/rules/cross_sample/17_mothur_remove.smk"
include: "workflow/rules/cross_sample/18_mothur_split.smk"
include: "workflow/rules/cross_sample/19_uparse_format.smk"
include: "workflow/rules/cross_sample/20_merge_uparse.smk"
include: "workflow/rules/cross_sample/21_uparse_sortbysize.smk"
include: "workflow/rules/cross_sample/22_uparse_cluster.smk"
include: "workflow/rules/cross_sample/23_uparse_map.smk"


onstart:
    shell(f"{sys.executable} workflow/scripts/validate_inputs.py config/config.yaml config/samples.tsv")


rule all:
    input:
        expand("results/{run}/final/OCTOPUS_OTUs.fasta", run=RUN),
        expand("results/{run}/final/OCTOPUS.shared", run=RUN),
        expand("results/{run}/final/OCTOPUS.biom", run=RUN),
        expand("results/{run}/final/OCTOPUS_otutab_txt", run=RUN),
