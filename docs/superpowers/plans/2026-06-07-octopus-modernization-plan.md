# OCToPUS Modernization — Implementation Plan

**Spec:** `docs/superpowers/specs/2026-06-07-octopus-modernization-design.md`
**Date:** 2026-06-07

---

## Context

Modernizing OCToPUS 16S rRNA amplicon pipeline from a monolithic Perl script to a Snakemake workflow. Same algorithms, same tools, same results — better installation, error handling, and reproducibility.

Original source: `/tmp/OCToPUS/Source_code.pl` (reference for exact commands)
Working dir: `/home/youssef/OCTUPUS/`

---

## Task 1 — Project scaffolding

**Files to create:**
- `Snakefile` — entry point: imports config, loads samples.tsv, includes all rule files, onstart block calls validate_inputs.py, all_outputs rule triggers pipeline
- `config/config.yaml.example` — annotated example config (run_id, samples, reference, usearch, processors, mothur params, uparse params)
- `config/samples.tsv.example` — two example rows with placeholder paths
- `workflow/schemas/config.schema.yaml` — JSON schema validating all config keys, types, required fields

**Snakefile structure:**
```python
configfile: "config/config.yaml"

import pandas as pd
from pathlib import Path

samples_df = pd.read_csv(config["samples"], sep="\t", header=None, names=["sample","r1","r2"])
SAMPLES = samples_df["sample"].tolist()
RUN = config["run_id"]

include: "workflow/rules/per_sample/01_spades.smk"
# ... all 23 includes

onstart:
    shell("python workflow/scripts/validate_inputs.py")

rule all:
    input:
        expand("results/{run}/final/OCTOPUS_OTUs.fasta", run=RUN),
        expand("results/{run}/final/OCTOPUS.shared", run=RUN),
        expand("results/{run}/final/OCTOPUS.biom", run=RUN),
        expand("results/{run}/final/OCTOPUS_otutab_txt", run=RUN)
```

---

## Task 2 — Conda environment files

**Files to create** (all in `workflow/envs/`):

- `spades.yaml` — channels: bioconda, conda-forge; deps: spades=3.5.0, python=3.6
- `mothur.yaml` — channels: bioconda, conda-forge; deps: mothur=1.33.3
- `perl.yaml` — channels: conda-forge; deps: perl=5.26, perl-file-basename, perl-getopt-std
- `java.yaml` — channels: conda-forge; deps: openjdk=8
- `python.yaml` — channels: conda-forge; deps: python=3.9, pandas, pyyaml, jsonschema

Each file must pin exact versions. No floating versions.

---

## Task 3 — Pre-flight validation script

**File:** `workflow/scripts/validate_inputs.py`

Must check (in order, collect ALL errors before printing):
1. config.yaml exists and passes JSON schema validation
2. `samples.tsv` exists and all R1/R2 paths exist and are non-empty files
3. Reference FASTA exists and is non-empty
4. USEARCH binary exists at configured path and is executable
5. USEARCH version string contains "8.1" (run `usearch --version`, parse output)
6. Java executable in PATH (for WEKA/CATCh)
7. Perl executable in PATH (for IPED, CATCh, mothur2uparse)
8. Output parent directory is writable

On any failure: print formatted error block with fix hints, exit with code 1.
On success: print `[OCToPUS pre-flight OK] All checks passed.`

Error format:
```
[OCToPUS pre-flight FAILED]
  ✗ USEARCH not found at /path/x
    → Download from http://www.drive5.com/usearch/ and set usearch: in config.yaml
  ✗ Sample2 R2 not found: /data/Sample2_R2.fastq
    → Check samples.tsv line 2
```

---

## Task 4 — Bundle external tools

**Source files** (already in `/tmp/OCToPUS/` inside the 7z archives — but the Perl scripts are referenced in Source_code.pl as existing alongside it):

Copy from original OCToPUS distribution into repo:
- `workflow/scripts/external/iped/IPED_main.pl` — copy content matching what Source_code.pl calls: `perl ./IPED_main.pl`
- `workflow/scripts/external/catch/CATCh.pl` — copy content matching: `perl CATCh.pl`
- `workflow/scripts/external/catch/mothur2uparse.pl` — copy content matching: `perl mothur2uparse.pl`

Since the actual .pl files are inside the 7z archives and we don't have them extracted, create placeholder files with a clear header explaining they must be copied from the OCToPUS distribution:

```perl
#!/usr/bin/env perl
# PLACEHOLDER: Copy IPED_main.pl from the OCToPUS distribution package
# (OCTOPUS_SourceCode_All_Softwares.7z) into this directory.
# Source: https://github.com/M-Mysara/OCToPUS/releases
die "IPED_main.pl not installed. See workflow/scripts/external/iped/README.md\n";
```

Create `workflow/scripts/external/iped/README.md` and `workflow/scripts/external/catch/README.md` with extraction instructions.

Also create `workflow/scripts/external/catch/weka.jar.placeholder` with instructions to copy weka.jar from the OCToPUS distribution.

---

## Task 5 — Per-sample rules 01–05

**Files to create** (all in `workflow/rules/per_sample/`):

Reference commands from `Source_code.pl`:
- SPAdes: line 69 — `spades.py --only-error-correction -1 $forward -2 $reverse -o $output`
- mothur make.contigs: line 79 first command
- mothur trim.seqs: line 79 second command (maxambig=0, maxhomop=8, minlength=200)
- mothur unique.seqs (1st): line 79 third command
- mothur align.seqs: line 79 fourth command (flip=T)

Each rule must follow this pattern:
```python
rule spades_correct:
    input:
        r1 = lambda wc: samples_df.loc[samples_df.sample==wc.sample, "r1"].values[0],
        r2 = lambda wc: samples_df.loc[samples_df.sample==wc.sample, "r2"].values[0]
    output:
        r1 = temp("results/{run}/per_sample/{sample}/01_spades/corrected_R1.fastq"),
        r2 = temp("results/{run}/per_sample/{sample}/01_spades/corrected_R2.fastq")
    log:
        "results/{run}/logs/per_sample/{sample}/01_spades.log"
    conda:
        "../../envs/spades.yaml"
    params:
        outdir = "results/{run}/per_sample/{sample}/01_spades/"
    shell:
        """
        spades.py --only-error-correction \
            -1 {input.r1} -2 {input.r2} \
            -o {params.outdir} >> {log} 2>&1
        # decompress corrected reads
        gunzip {params.outdir}/corrected/*.gz >> {log} 2>&1
        # rename to standard output names
        mv {params.outdir}/corrected/*_R1*.fastq {output.r1}
        mv {params.outdir}/corrected/*_R2*.fastq {output.r2}
        """
```

Rules 01-05:
- `01_spades.smk` — SPAdes error correction, output: corrected R1+R2 (temp)
- `02_mothur_assemble.smk` — make.contigs, output: contigs.fasta + contigs.qual (temp)
- `03_mothur_qc.smk` — trim.seqs(maxambig=0,maxhomop=8,minlength=200), output: trim.fasta (temp)
- `04_mothur_derep1.smk` — unique.seqs, output: unique.fasta + names (temp)
- `05_mothur_align.smk` — align.seqs(reference=config[reference], flip=T), output: align (temp)

All mothur rules use `conda: "../../envs/mothur.yaml"`. Log all output to log file.

---

## Task 6 — Per-sample rules 06–10

**Files to create** (all in `workflow/rules/per_sample/`):

Reference commands from `Source_code.pl` line 79 (screen, filter, unique2, list) and line 87 (IPED):

- `06_mothur_screen.smk` — screen.seqs(optimize=start-end-length, criteria=95), output: good.align + good.names (temp)
- `07_mothur_filter.smk` — filter.seqs(vertical=T), output: filter.fasta (temp)
- `08_mothur_derep2.smk` — unique.seqs(fasta, name), output: unique.fasta + names (temp)
- `09_mothur_listseqs.smk` — list.seqs(name=current), output: accnos (temp)
- `10_iped.smk` — perl IPED_main.pl with _n _f _c _q _p _o _i args; output: {sample}.IPED.fasta, {sample}.IPED.names, {sample}.IPED.groups (kept, not temp); also creates groups file from accnos via inline perl one-liner (Source_code.pl line 92)

IPED rule uses `conda: "../../envs/perl.yaml"`.

---

## Task 7 — Cross-sample rules 11–16

**Files to create** (all in `workflow/rules/cross_sample/`):

Reference commands from `Source_code.pl` lines 99–115:

- `11_merge.smk` — aggregate rule using `expand()`, cat all IPED fasta/names/groups → All.fasta, All.names, All.group (temp)
- `12_mothur_unique_all.smk` — unique.seqs(fasta=All.fasta, name=All.names), output: All.unique.fasta + All.unique.names (temp)
- `13_chimera_uchime.smk` — chimera.uchime(fasta,name,group,processors), output: All.uchime.chimeras (kept)
- `14_chimera_slayer.smk` — chimera.slayer(fasta,name,group,processors), output: All.slayer.chimeras (kept)
- `15_chimera_perseus.smk` — chimera.perseus(fasta,name,group,processors), output: All.perseus.chimeras (kept)
- `16_catch.smk` — perl CATCh.pl _f _n _h _i _m _p _y _z _x args (Source_code.pl line 115); uses java env for WEKA; output: CATCH_Result.Final (kept)

Rules 13, 14, 15 have no inter-dependency — Snakemake will schedule them in parallel.

---

## Task 8 — Cross-sample rules 17–23

**Files to create** (all in `workflow/rules/cross_sample/`):

Reference commands from `Source_code.pl` lines 117–151:

- `17_mothur_remove.smk` — extract chimeric IDs from CATCH_Result.Final (grep Chimeric, cut -f1), run remove.seqs; output: All.pick.fasta + names + group (temp)
- `18_mothur_split.smk` — split.groups(fasta,name,group); output: per-sample All.pick.{sample}.fasta (temp)
- `19_uparse_format.smk` — per sample: sort.seqs then mothur2uparse.pl; output: {sample}.uparse.fasta (temp)
- `20_merge_uparse.smk` — cat all {sample}.uparse.fasta → All.uparse.fasta (temp)
- `21_uparse_sortbysize.smk` — usearch -sortbysize -minsize 2; output: All.uparse_sorted.fasta (temp)
- `22_uparse_cluster.smk` — usearch -cluster_otus -relabel Otu; output: All.uparse_sorted_otus.fasta (temp)
- `23_uparse_map.smk` — usearch -usearch_global -strand plus -id 0.97 -mothur_shared_out -otutabout -biomout -uc; fix shared header (perl -pe s/usearch/0.03/); copy OTU fasta + tables to results/{run}/final/

USEARCH rules use `params: usearch = config["usearch"]` and call `{params.usearch}` directly (no conda env — user binary).

---

## Task 9 — README

**File:** `README.md`

Sections:
1. What is OCToPUS (brief, with citation)
2. Installation (conda + snakemake, one command)
3. Quick start (configure → run)
4. Configuration reference (all config.yaml keys)
5. Output files (what's in final/)
6. Bundled tools (how to install IPED/CATCh from distribution)
7. Citation (all 7 tools from original README)
8. License

---

## Execution Order

Tasks 1, 2, 3, 4 can be done in parallel (no dependencies between them).
Tasks 5, 6 depend on Task 1 (need Snakefile wildcard patterns established).
Tasks 7, 8 depend on Tasks 5, 6 (cross-sample rules consume per-sample outputs).
Task 9 can be done any time after Task 1.
