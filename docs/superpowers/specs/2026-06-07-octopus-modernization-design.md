# OCToPUS Modernization — Design Spec

**Date:** 2026-06-07
**Author:** M. Mysara et al. / modernization
**Status:** Approved

---

## 1. Problem Statement

OCToPUS (Optimized CATCh, mothur, IPED, UPARSE and SPAdes) is a 16S rRNA amplicon sequencing pipeline published in GigaScience 2017. The original implementation has three critical problems:

1. **Installation failures** — old Perl orchestrator, tool versions not pinned, missing dependency detection before runtime
2. **Poor error handling** — silent failures, cryptic tool-level errors with no sample/stage context, no restart capability
3. **Version chaos** — results differ across machines due to uncontrolled tool versions

---

## 2. Goals

- **Research use:** pipeline must run reliably on user's own samples
- **Publishable contribution:** modernized implementation must be citable and shareable
- **Same algorithms:** preserve exact tool chain (SPAdes → mothur → IPED → CATCh → UPARSE) to maintain citability and reproducibility claim
- **Cross-machine reproducibility:** identical results on any PC or HPC node

---

## 3. Non-Goals

- Replacing algorithms with modern equivalents (DADA2, vsearch, etc.)
- Cloud deployment (AWS, GCP)
- GUI or web interface
- Nextflow implementation

---

## 4. Technology Choices

| Concern | Choice | Reason |
|---------|--------|--------|
| Orchestrator | Snakemake | Standard in modern bioinformatics, publishable, HPC-compatible, native conda integration, restartability |
| Reproducibility | Conda per-rule environments | HPC-friendly (no Docker needed), pins exact versions, `--use-conda` builds automatically |
| Language | Python (scripts) + Snakemake DSL | Replaces Perl orchestrator; better ecosystem, error handling, validation |

---

## 5. Architecture

### 5.1 Project Structure

```
octopus-snakemake/
│
├── Snakefile                          # entry point, onstart validation, rule includes
├── config/
│   ├── config.yaml                    # all parameters
│   └── samples.tsv                    # SampleID  R1.fastq  R2.fastq
│
├── workflow/
│   ├── rules/
│   │   ├── per_sample/
│   │   │   ├── 01_spades.smk
│   │   │   ├── 02_mothur_assemble.smk
│   │   │   ├── 03_mothur_qc.smk
│   │   │   ├── 04_mothur_derep1.smk
│   │   │   ├── 05_mothur_align.smk
│   │   │   ├── 06_mothur_screen.smk
│   │   │   ├── 07_mothur_filter.smk
│   │   │   ├── 08_mothur_derep2.smk
│   │   │   ├── 09_mothur_listseqs.smk
│   │   │   └── 10_iped.smk
│   │   └── cross_sample/
│   │       ├── 11_merge.smk
│   │       ├── 12_mothur_unique_all.smk
│   │       ├── 13_chimera_uchime.smk
│   │       ├── 14_chimera_slayer.smk
│   │       ├── 15_chimera_perseus.smk
│   │       ├── 16_catch.smk
│   │       ├── 17_mothur_remove.smk
│   │       ├── 18_mothur_split.smk
│   │       ├── 19_uparse_format.smk
│   │       ├── 20_merge_uparse.smk
│   │       ├── 21_uparse_sortbysize.smk
│   │       ├── 22_uparse_cluster.smk
│   │       └── 23_uparse_map.smk
│   ├── envs/
│   │   ├── spades.yaml
│   │   ├── mothur.yaml
│   │   ├── perl.yaml
│   │   ├── java.yaml
│   │   └── python.yaml
│   ├── scripts/
│   │   ├── validate_inputs.py
│   │   └── external/
│   │       ├── iped/
│   │       │   └── IPED_main.pl
│   │       └── catch/
│   │           ├── CATCh.pl
│   │           ├── mothur2uparse.pl
│   │           └── weka.jar
│   └── schemas/
│       └── config.schema.yaml
│
└── results/{run_id}/
    ├── per_sample/{sample}/01_spades/ ... 10_iped/
    ├── cross_sample/11_merge/ ... 23_uparse_map/
    ├── final/
    └── logs/
```

### 5.2 Rule Breakdown (23 rules)

Each rule lives in its own `.smk` file. One rule = one tool invocation = one error boundary.

#### Per-sample rules (rules 01–10, parallelized across samples)

| Rule file | Operation | Tool | Input | Output |
|-----------|-----------|------|-------|--------|
| `01_spades.smk` | Pre-assembly error correction | SPAdes 3.5.0 | raw R1, R2 fastq | corrected R1, R2 fastq |
| `02_mothur_assemble.smk` | Paired-end assembly | mothur 1.33.3 `make.contigs` | corrected R1, R2 | contigs.fasta, contigs.qual |
| `03_mothur_qc.smk` | Quality filtering | mothur `trim.seqs` | contigs.fasta | trim.fasta |
| `04_mothur_derep1.smk` | 1st dereplication | mothur `unique.seqs` | trim.fasta | unique.fasta, names |
| `05_mothur_align.smk` | Reference alignment | mothur `align.seqs` | unique.fasta, SILVA | align |
| `06_mothur_screen.smk` | Alignment screening | mothur `screen.seqs` | align, names | good.align, good.names |
| `07_mothur_filter.smk` | Gap column removal | mothur `filter.seqs` | good.align | filter.fasta |
| `08_mothur_derep2.smk` | 2nd dereplication | mothur `unique.seqs` | filter.fasta | unique.fasta, names |
| `09_mothur_listseqs.smk` | Accession list export | mothur `list.seqs` | names | accnos |
| `10_iped.smk` | ML denoising | IPED v1 | fasta, names, qual, accnos | IPED.fasta, IPED.names, IPED.groups |

#### Cross-sample rules (rules 11–23, run after all samples complete)

| Rule file | Operation | Tool | Input | Output |
|-----------|-----------|------|-------|--------|
| `11_merge.smk` | Merge all sample outputs | cat | all IPED fasta/names/groups | All.fasta, All.names, All.group |
| `12_mothur_unique_all.smk` | Pre-chimera dereplication | mothur `unique.seqs` | All.fasta, All.names | All.unique.fasta, All.unique.names |
| `13_chimera_uchime.smk` | UCHIME chimera detection | mothur `chimera.uchime` | All.unique.fasta | All.uchime.chimeras |
| `14_chimera_slayer.smk` | ChimeraSlayer detection | mothur `chimera.slayer` | All.unique.fasta | All.slayer.chimeras |
| `15_chimera_perseus.smk` | Perseus chimera detection | mothur `chimera.perseus` | All.unique.fasta | All.perseus.chimeras |
| `16_catch.smk` | ML ensemble chimera classifier | CATCh.pl + WEKA | 3 chimera files | CATCH_Result.Final |
| `17_mothur_remove.smk` | Remove chimeric sequences | mothur `remove.seqs` | All.fasta + chimera accnos | All.pick.fasta/names/group |
| `18_mothur_split.smk` | Split back to per-sample | mothur `split.groups` | All.pick.fasta/names/group | All.pick.{sample}.fasta |
| `19_uparse_format.smk` | Convert mothur → USEARCH format | mothur `sort.seqs` + mothur2uparse.pl | per-sample fasta/names | {sample}.uparse.fasta |
| `20_merge_uparse.smk` | Merge UPARSE-format fastas | cat | all {sample}.uparse.fasta | All.uparse.fasta |
| `21_uparse_sortbysize.smk` | Filter singletons | USEARCH `-sortbysize` | All.uparse.fasta | All.uparse_sorted.fasta |
| `22_uparse_cluster.smk` | OTU clustering at 97% | USEARCH `-cluster_otus` | All.uparse_sorted.fasta | All.uparse_sorted_otus.fasta |
| `23_uparse_map.smk` | Map reads → OTUs, emit tables | USEARCH `-usearch_global` | sorted fasta + OTUs | .shared, .biom, _otutab_txt, .mapping |

Rules 13, 14, 15 have no dependency on each other — Snakemake schedules them in parallel automatically.

### 5.3 Conda Environments (per-rule)

Each rule declares `conda: "../envs/tool.yaml"`. Snakemake builds and caches envs on first run. `snakemake --use-conda` on any new machine = automatic environment setup.

```
workflow/envs/
├── spades.yaml      # spades=3.5.0, python=3.6
├── mothur.yaml      # mothur=1.33.3
├── perl.yaml        # perl=5.x + required modules (for IPED, CATCh, mothur2uparse)
├── java.yaml        # openjdk=8 (for WEKA jar inside CATCh)
└── python.yaml      # python=3.9+ (for validation scripts)
```

Each `.yaml` pins exact versions:
```yaml
channels:
  - bioconda
  - conda-forge
  - defaults
dependencies:
  - spades=3.5.0
  - python=3.6.15
```

### 5.4 Tool Ownership

| Tool | Source | Conda env | Special handling |
|------|--------|-----------|-----------------|
| SPAdes 3.5.0 | bioconda | spades.yaml | — |
| mothur 1.33.3 | bioconda | mothur.yaml | — |
| IPED_main.pl | bundled in repo | perl.yaml | `workflow/scripts/external/iped/` |
| CATCh.pl | bundled in repo | perl.yaml | `workflow/scripts/external/catch/` |
| WEKA 3.7.11 jar | bundled in repo | java.yaml | `workflow/scripts/external/catch/weka.jar` |
| mothur2uparse.pl | bundled in repo | perl.yaml | `workflow/scripts/external/catch/` |
| USEARCH 8.1.1861 | user-supplied | — | path from `config.yaml`; license prevents distribution |

IPED, CATCh, and mothur2uparse are GPL licensed — safe to bundle in repository.

---

## 6. Configuration

### config/config.yaml

```yaml
run_id: "test_run"                     # output subfolder name; default: ISO timestamp

# Mandatory
samples: "config/samples.tsv"
reference: "/full/path/silva.bacteria.fasta"
usearch: "/full/path/usearch8.1.1861"  # user-supplied binary

# Resources
processors: 8

# mothur QC parameters (match original defaults)
mothur:
  maxambig: 0
  maxhomop: 8
  minlength: 200
  align_criteria: 95

# UPARSE parameters (match original defaults)
uparse:
  min_size: 2
  identity: 0.97
```

### config/samples.tsv

```
Sample1    /full/path/Sample1_R1.fastq    /full/path/Sample1_R2.fastq
Sample2    /full/path/Sample2_R1.fastq    /full/path/Sample2_R2.fastq
```

Tab-separated. Same content as original stability file, same format.

### workflow/schemas/config.schema.yaml

Validates `config.yaml` against a JSON schema at startup. Catches missing keys, wrong types, invalid paths before any rule runs.

---

## 7. Output Structure

```
results/{run_id}/
├── per_sample/{sample}/
│   ├── 01_spades/          corrected_R1.fastq [temp], corrected_R2.fastq [temp]
│   ├── 02_mothur_assemble/ {sample}.contigs.fasta [temp], {sample}.contigs.qual [temp]
│   ├── 03_mothur_qc/       {sample}.trim.fasta [temp]
│   ├── 04_mothur_derep1/   {sample}.unique.fasta [temp], {sample}.names [temp]
│   ├── 05_mothur_align/    {sample}.align [temp]
│   ├── 06_mothur_screen/   {sample}.good.align [temp], {sample}.good.names [temp]
│   ├── 07_mothur_filter/   {sample}.filter.fasta [temp]
│   ├── 08_mothur_derep2/   {sample}.unique.fasta [temp], {sample}.names [temp]
│   ├── 09_mothur_listseqs/ {sample}.accnos [temp]
│   └── 10_iped/            {sample}.IPED.fasta [kept], {sample}.IPED.names [kept], {sample}.IPED.groups [kept]
│
├── cross_sample/
│   ├── 11_merge/           All.fasta [temp], All.names [temp], All.group [temp]
│   ├── 12_mothur_unique_all/ All.unique.fasta [temp], All.unique.names [temp]
│   ├── 13_chimera_uchime/  All.uchime.chimeras [kept]
│   ├── 14_chimera_slayer/  All.slayer.chimeras [kept]
│   ├── 15_chimera_perseus/ All.perseus.chimeras [kept]
│   ├── 16_catch/           CATCH_Result.Final [kept]
│   ├── 17_mothur_remove/   All.pick.fasta [temp], All.pick.names [temp], All.pick.group [temp]
│   ├── 18_mothur_split/    All.pick.{sample}.fasta [temp] (per sample)
│   ├── 19_uparse_format/   {sample}.uparse.fasta [temp] (per sample)
│   ├── 20_merge_uparse/    All.uparse.fasta [temp]
│   ├── 21_uparse_sortbysize/ All.uparse_sorted.fasta [temp]
│   ├── 22_uparse_cluster/  All.uparse_sorted_otus.fasta [temp]
│   └── 23_uparse_map/      OCTOPUS.shared [temp→final], OCTOPUS.biom [temp→final],
│                           OCTOPUS_otutab_txt [temp→final], All.uparse.mapping [temp]
│
├── final/                  OCTOPUS_OTUs.fasta, OCTOPUS.shared, OCTOPUS.biom, OCTOPUS_otutab_txt
└── logs/
    ├── per_sample/{sample}/  01_spades.log … 10_iped.log
    └── cross_sample/         11_merge.log … 23_uparse_map.log
```

**[temp]** — marked as `temp()` in Snakemake rule; deleted automatically after downstream rule consumes them. Saves disk on large datasets.

**[kept]** — not marked temp; preserved for inspection and debugging.

**final/** — always preserved; user-facing outputs identical to original OCToPUS output filenames.

---

## 8. Error Handling

### 8.1 Pre-flight validation (onstart block)

`workflow/scripts/validate_inputs.py` runs before any rule. Checks:

1. All tool binaries exist and are executable: mothur, SPAdes python entry, USEARCH
2. Tool versions match expected: mothur=1.33.3, SPAdes=3.5.0, USEARCH=8.1.x
3. All R1/R2 files listed in `samples.tsv` exist and are non-empty
4. Reference FASTA exists and is non-empty
5. USEARCH executable at configured path is functional
6. Output directory parent is writable
7. Java available (for WEKA/CATCh)
8. Perl available (for IPED, CATCh, mothur2uparse)

Failure output:
```
[OCToPUS pre-flight FAILED]
  ✗ USEARCH not found at /home/user/usearch8.1.1861
    → Download from http://www.drive5.com/usearch/ and update config.yaml: usearch:
  ✗ Sample2 reverse file not found: /data/Sample2_R2.fastq
    → Check samples.tsv line 2
```

### 8.2 Runtime errors

Each rule:
- Writes full stdout + stderr to `logs/{stage}/{sample}.log`
- On failure, Snakemake prints: rule name, sample wildcard, last 20 lines of log
- Shell commands use `2>> {log}` to capture all tool output

Error output example:
```
Error in rule 05_mothur_align (sample: Sample3):
  → Check log: results/run1/logs/per_sample/Sample3/05_mothur_align.log
  → Last lines:
    [ERROR]: Reference alignment file not found...
```

### 8.3 Restartability

Snakemake tracks completed rules via output file existence. Crash mid-run → rerun same command → resumes from last completed rule. No data loss, no reprocessing of completed samples.

---

## 9. Execution

### Install

```bash
conda create -n octopus-snakemake snakemake
conda activate octopus-snakemake
```

### Configure

```bash
cp config/config.yaml.example config/config.yaml
# edit: samples, reference, usearch paths
```

### Run

```bash
snakemake --use-conda --cores 8
```

### Dry run (preview without executing)

```bash
snakemake --use-conda --cores 8 --dry-run
```

### Resume after crash

```bash
snakemake --use-conda --cores 8   # same command, resumes automatically
```

---

## 10. Testing Strategy

- **Integration test:** small synthetic dataset (2 samples, 1000 reads each) with known ground truth OTUs
- **Per-rule smoke tests:** verify each rule's output file exists and is non-empty after running on test data
- **Regression test:** run on original OCToPUS test dataset; compare final OTU table to original Perl pipeline output
- **Pre-flight test:** deliberately corrupt inputs and verify each pre-flight check fires with correct message

---

## 11. Deliverables

1. `Snakefile` — entry point with onstart validation and rule includes
2. `workflow/rules/per_sample/` — 10 rule files
3. `workflow/rules/cross_sample/` — 13 rule files
4. `workflow/envs/` — 5 conda environment YAML files
5. `workflow/scripts/validate_inputs.py` — pre-flight validator
6. `workflow/scripts/external/` — bundled IPED, CATCh, WEKA, mothur2uparse
7. `workflow/schemas/config.schema.yaml` — config validator
8. `config/config.yaml.example` — annotated example config
9. `config/samples.tsv.example` — example sample sheet
10. `README.md` — installation + usage instructions
