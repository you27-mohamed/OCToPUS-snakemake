# OCToPUS — Snakemake Pipeline

> **Ensemble 16S rRNA amplicon sequencing pipeline**
> SPAdes error correction → mothur QC → IPED denoising → CATCh/WEKA chimera detection → UPARSE OTU clustering

[![Snakemake](https://img.shields.io/badge/snakemake-≥9.0-brightgreen)](https://snakemake.readthedocs.io)
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20x86--64-lightgrey)](https://www.linux.org)
[![Python](https://img.shields.io/badge/python-3.11-blue)](https://www.python.org)
[![Upstream](https://img.shields.io/badge/upstream-M--Mysara%2FOCToPUS-orange)](https://github.com/M-Mysara/OCToPUS)

> **This repository is a Snakemake modernization of the original OCToPUS pipeline.**
> Original monolithic Perl implementation: [M-Mysara/OCToPUS](https://github.com/M-Mysara/OCToPUS)
> Same algorithms · Same tools · Same results — with parallelism, conda environments, structured logs, and automatic restartability.

---

## Table of Contents

- [What is OCToPUS?](#what-is-octopus)
- [How it Works](#how-it-works)
- [Pipeline Topology](#pipeline-topology)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Quick Setup (setup.sh)](#quick-setup-setupsh)
- [Manual Configuration](#manual-configuration)
- [Preparing Your Samples](#preparing-your-samples)
- [Running the Pipeline](#running-the-pipeline)
- [Monitoring Progress](#monitoring-progress)
- [Output Files](#output-files)
- [Configuration Reference](#configuration-reference)
- [Threading Model](#threading-model)
- [Bundled Tools](#bundled-tools)
- [Portability — Moving to Another Machine](#portability--moving-to-another-machine)
- [Upstream Repository](#upstream-repository)
- [Citation](#citation)
- [License](#license)

---

## What is OCToPUS?

OCToPUS (**O**TU **C**lustering **T**hrough an **O**ptimal **P**ipeline **U**sing ensemble**S**) is a 16S rRNA MiSeq amplicon sequencing pipeline that combines multiple independent error-correction and chimera-detection algorithms into a single ensemble decision using machine learning.

By chaining SPAdes, mothur, IPED, CATCh/WEKA, and UPARSE, OCToPUS achieves:

- **Lower error rate** than single-tool approaches
- **Fewer spurious OTUs** — ML-based chimera classification outperforms any individual chimera detector
- **Higher read retention** — reads are only discarded when multiple independent methods agree

This repository modernizes the original monolithic Perl script into a **Snakemake workflow** with:

- Per-rule conda environments (reproducible, version-pinned)
- Automatic parallelism across samples and CPU cores
- Pre-flight input validation before any compute starts
- One log file per rule per sample — easy debugging
- Automatic resume after crash — never re-run completed steps

---

## How it Works

OCToPUS processes MiSeq paired-end reads through 23 rules in two phases:

**Per-sample phase (rules 01–10)** — each sample is processed independently and in parallel:

1. SPAdes BayesHammer corrects sequencing errors in raw reads
2. mothur assembles paired-end reads into contigs
3. mothur trims low-quality sequences and short reads
4. mothur removes duplicate sequences (1st dereplication)
5. mothur aligns to the SILVA reference database
6. mothur filters poorly-aligned sequences
7. mothur removes gap-only alignment columns
8. mothur removes duplicates again (2nd dereplication after filtering)
9. mothur exports the sequence accession list
10. IPED applies ML-based paired-end denoising

**Cross-sample phase (rules 11–23)** — all samples merged and processed together:

11. Merge all IPED outputs into a single file
12. Global dereplication across all samples
13–15. Three independent chimera detectors run in parallel (UCHIME, ChimeraSlayer, Perseus)
16. CATCh/WEKA ML ensemble combines the three chimera calls → single final decision
17. Remove all chimeric sequences
18. Split back into per-sample groups
19. Convert to UPARSE format
20. Merge all samples for OTU clustering
21–22. USEARCH sorts, filters singletons, and clusters at 97% identity
23. USEARCH maps reads back to OTUs → 4 output formats

---

## Pipeline Topology

```
 INPUTS
 ──────
 R1.fastq.gz ──┐
 R2.fastq.gz ──┤  (one pair per sample)
                │
                ▼
┌──────────────────────────────────────────────────────────────────┐
│  PER-SAMPLE  (all samples run in parallel, up to --cores limit)  │
│                                                                  │
│  01  SPAdes        BayesHammer error correction                  │
│        │                                                         │
│  02  mothur        make.contigs   (paired-end assembly)          │
│        │                                                         │
│  03  mothur        trim.seqs      (quality filter)               │
│        │                                                         │
│  04  mothur        unique.seqs    (1st dereplication)            │
│        │                                                         │
│  05  mothur *      align.seqs     (SILVA reference alignment)    │
│        │                                                         │
│  06  mothur        screen.seqs    (alignment screening)          │
│        │                                                         │
│  07  mothur        filter.seqs    (remove gap columns)           │
│        │                                                         │
│  08  mothur        unique.seqs    (2nd dereplication)            │
│        │                                                         │
│  09  mothur        list.seqs      (export accession list)        │
│        │                                                         │
│  10  IPED          ML-based paired-end denoising                 │
│        │                                                         │
└────────┼─────────────────────────────────────────────────────────┘
         │  (all samples collected here)
         ▼
┌──────────────────────────────────────────────────────────────────┐
│  CROSS-SAMPLE                                                    │
│                                                                  │
│  11  merge         cat all IPED outputs → All.fasta              │
│        │                                                         │
│  12  mothur        unique.seqs    (global dereplication)         │
│        │                                                         │
│        ├───────────────────┬──────────────────┐                  │
│        ▼                   ▼                  ▼                  │
│   13 UCHIME          14 ChimeraSlayer   15 Perseus               │
│   (parallel)          (parallel)         (parallel †)            │
│        │                   │                  │                  │
│        └───────────────────┴──────────────────┘                  │
│                            │                                     │
│  16  CATCh + WEKA    ensemble ML chimera classifier              │
│                            │                                     │
│  17  mothur          remove.seqs    (discard chimeras)           │
│                            │                                     │
│  18  mothur          split.groups   (back to per-sample)         │
│                            │                                     │
│  19  mothur + perl   convert to UPARSE format (per sample)       │
│                            │                                     │
│  20  merge           cat all UPARSE-format files → All           │
│                            │                                     │
│  21  USEARCH         sortbysize     (filter singletons)          │
│                            │                                     │
│  22  USEARCH         cluster_otus   (97% identity OTUs)          │
│                            │                                     │
│  23  USEARCH         usearch_global (map reads → OTUs)           │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             ▼
 OUTPUTS   results/{run_id}/final/
 ──────────────────────────────────────────────────────────────────
  OCTOPUS_OTUs.fasta      OTU representative sequences
  OCTOPUS.shared          OTU abundance table  (mothur format)
  OCTOPUS.biom            OTU abundance table  (BIOM / QIIME2)
  OCTOPUS_otutab_txt      OTU abundance table  (tab-separated)
```

> `*` Rule 05 uses multi-threaded mothur 1.48.0 (via conda). All other mothur rules use the bundled modified mothur 1.33.3 for IPED/CATCh compatibility.
>
> `†` Rule 15 (Perseus) runs as 93 independent per-sample jobs in parallel (up to `--cores` limit) — not a single serial process.
>
> Rules 13, 14, 15 are **DAG-independent** — Snakemake runs all three simultaneously.

---

## System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Linux x86-64 | Linux x86-64 |
| RAM | 20 GB | 32 GB+ |
| CPU | 4 cores | 28–32 cores |
| Disk | 50 GB free | 200 GB+ |
| Conda | Any version | Miniconda3 |
| Snakemake | ≥ 9.0 | Latest |

> **macOS and Windows are not supported.** Bundled binaries (mothur 1.33.3, uchime, BLAST legacy) are Linux x86-64 ELF executables.

> **RAM note:** mothur `align.seqs` loads the SILVA reference into RAM (~14 GB). The pipeline enforces only one SILVA load at a time via `--resources mem_mb=14000`. Minimum usable RAM is ~20 GB.

---

## Installation

### Step 1 — Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/octopus-snakemake.git
cd octopus-snakemake
```

### Step 2 — Install Miniconda (if not already installed)

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
# Follow prompts, then restart shell or: source ~/.bashrc
```

### Step 3 — Create the OCToPUS conda environment

This installs Snakemake and all Python dependencies in one step using the pinned environment file:

```bash
conda env create -f environment.yml
conda activate octopus
```

> The `environment.yml` was exported from a tested working installation and pins all package versions for reproducibility. If you prefer a looser install, use `environment.minimal.yml` instead:
> ```bash
> conda env create -f environment.minimal.yml
> ```

### Step 4 — Download the SILVA reference

The SILVA nr_v132 reference alignment is required for mothur's `align.seqs` step (~3.4 GB):

```bash
mkdir -p data
cd data
# Download from mothur's website:
wget https://mothur.s3.us-east-2.amazonaws.com/wiki/silva.nr_v132.tgz
tar -xzf silva.nr_v132.tgz
# You need the file: silva.nr_v132.align
cd ..
```

> If you already have `silva.nr_v132.align` on your system, you can point the config to its existing location — no need to re-download.

### Step 5 — Get USEARCH 8.1.1861

USEARCH has a restrictive license that prevents redistribution. You must download it yourself:

1. Go to [drive5.com/usearch/download.html](http://www.drive5.com/usearch/download.html)
2. Request the free 32-bit binary for Linux
3. You will receive a download link by email
4. Download and make it executable:

```bash
chmod +x /path/to/usearch8.1.1861
```

---

## Quick Setup (setup.sh)

The easiest way to configure the pipeline on any machine — run the interactive wizard:

```bash
conda activate octopus
bash setup.sh
```

The wizard asks 6 questions:

```
[1/6] Run ID           — name for this study's output folder
[2/6] Samples file     — path to your samples TSV
[3/6] SILVA reference  — auto-detects common locations, or enter path manually
[4/6] USEARCH binary   — auto-detects common locations, auto-fixes permissions
[5/6] CPU cores        — auto-detects your machine, recommends safe value
[6/6] QC parameters    — use OCToPUS defaults or customize
```

When done, it writes `config/config.yaml` and prints the exact commands to run the pipeline.

---

## Manual Configuration

If you prefer to configure manually, copy the example and edit:

```bash
cp config/config.yaml.example config/config.yaml
```

Edit `config/config.yaml`:

```yaml
run_id:    "study1"                              # output goes to results/study1/
samples:   "config/samples.tsv"                  # path to your samples file
reference: "/path/to/silva.nr_v132.align"        # SILVA reference
usearch:   "/path/to/usearch8.1.1861"            # USEARCH binary
processors: 28                                   # CPU cores per tool

mothur:
  maxambig:       0    # max ambiguous bases (0 = none allowed)
  maxhomop:       8    # max homopolymer run length
  minlength:    200    # minimum sequence length after QC
  align_criteria: 95   # screen.seqs percentile cutoff

uparse:
  min_size:  2         # minimum cluster size (removes singletons)
  identity:  0.97      # OTU clustering identity threshold (97%)
```

---

## Preparing Your Samples

### Samples TSV format

Create `config/samples.tsv` — one sample per line, tab-separated:

```
# SampleID    R1                                    R2
Sample1        /data/Sample1_R1.fastq.gz             /data/Sample1_R2.fastq.gz
Sample2        /data/Sample2_R1.fastq.gz             /data/Sample2_R2.fastq.gz
Sample3        /data/Sample3_R1.fastq.gz             /data/Sample3_R2.fastq.gz
```

**Rules:**
- Column separator must be **tab** (not spaces)
- Lines starting with `#` are comments — ignored
- SampleID must be unique — used as folder name and sequence prefix
- R1/R2 paths can be absolute or relative to the project directory
- Both `.fastq` and `.fastq.gz` (gzipped) are supported

### Generate the samples file automatically

If your FASTQ files follow a standard naming pattern:

```bash
# Example: files named SRR8061715_1.fastq.gz and SRR8061715_2.fastq.gz
for r1 in /data/study1/*_1.fastq.gz; do
    r2="${r1/_1.fastq.gz/_2.fastq.gz}"
    sample=$(basename "$r1" _1.fastq.gz)
    printf "%s\t%s\t%s\n" "$sample" "$r1" "$r2"
done > config/samples.tsv
```

---

## Running the Pipeline

### 1. Validate inputs (strongly recommended before a long run)

Checks all 13 pre-conditions: config schema, sample files, SILVA reference, USEARCH version, Java, Perl, bundled binaries:

```bash
conda activate octopus
python workflow/scripts/validate_inputs.py config/config.yaml config/samples.tsv
```

Expected output on success:
```
[OCToPUS pre-flight OK] All 13 checks passed.
```

### 2. Dry run — preview all jobs without executing

```bash
snakemake --use-conda --cores 28 --dry-run
```

This shows every job that will run and in what order. No files are created.

### 3. Full run

```bash
# Run in foreground (will stop if terminal closes):
snakemake --use-conda --cores 28 --resources mem_mb=14000 2>&1 | tee results/run.log

# Run in background with nohup (survives SSH disconnect — recommended):
nohup snakemake --use-conda --cores 28 --resources mem_mb=14000 \
    > results/run.log 2>&1 &
echo "PID: $!"
```

> `--resources mem_mb=14000` limits SILVA database loading to one instance at a time, preventing out-of-memory crashes. **Always include this flag.**

### 4. Resume after crash

Snakemake tracks completed steps in `.snakemake/`. Simply re-run the same command — it picks up exactly where it stopped:

```bash
nohup snakemake --use-conda --cores 28 --resources mem_mb=14000 \
    >> results/run.log 2>&1 &
```

If you see a lock error after a crash:
```bash
snakemake --unlock
# then re-run as above
```

---

## Monitoring Progress

### Quick progress check

```bash
grep "steps.*done" results/run.log | tail -1
```

### Watch live

```bash
tail -f results/run.log
```

### Check which step is currently running

```bash
# See active tool processes:
pgrep -a mothur
pgrep -a spades
pgrep -a perl | grep -v grep
```

### Check for errors

```bash
grep -E "Error|error|failed|FAILED" results/run.log | grep -v "Read error correction"
```

### Check per-sample logs

Logs for each rule and each sample are in `results/{run_id}/logs/`:

```bash
# Example: check why align.seqs failed for a specific sample
cat results/study1/logs/per_sample/SRR8061715/05_mothur_align.log

# List all logs for a sample
ls results/study1/logs/per_sample/SRR8061715/
```

---

## Output Files

```
results/{run_id}/
│
├── final/                           ← MAIN OUTPUTS
│   ├── OCTOPUS_OTUs.fasta           OTU representative sequences (FASTA)
│   ├── OCTOPUS.shared               OTU abundance table (mothur format)
│   ├── OCTOPUS.biom                 OTU abundance table (BIOM / QIIME2)
│   └── OCTOPUS_otutab_txt           OTU abundance table (tab-separated)
│
├── per_sample/{sample}/
│   ├── 02_mothur_assemble/          Assembled contigs (kept)
│   └── 10_iped/                     IPED-denoised sequences (kept)
│   └── ...                          Intermediate files (auto-deleted to save disk)
│
├── cross_sample/
│   ├── 13_chimera_uchime/           UCHIME chimera calls (kept)
│   ├── 14_chimera_slayer/           ChimeraSlayer chimera calls (kept)
│   ├── 15_chimera_perseus/          Perseus chimera calls (kept)
│   └── 16_catch/                    CATCh ML ensemble result (kept)
│
└── logs/
    ├── per_sample/{sample}/         One .log per rule per sample
    └── cross_sample/                One .log per cross-sample rule
```

> Intermediate files (rules 01, 03–09, 11–12, 17–22) are marked `temp()` and automatically deleted after use to conserve disk space.

---

## Configuration Reference

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `run_id` | string | Output folder name under `results/` | required |
| `samples` | path | Path to samples TSV file | required |
| `reference` | path | Path to SILVA nr_v132 alignment | required |
| `usearch` | path | Path to USEARCH 8.1.1861 binary | required |
| `processors` | int | CPU threads per tool invocation | required |
| `mothur.maxambig` | int | Max ambiguous bases in trim.seqs | `0` |
| `mothur.maxhomop` | int | Max homopolymer length in trim.seqs | `8` |
| `mothur.minlength` | int | Min sequence length in trim.seqs | `200` |
| `mothur.align_criteria` | int | Percentile cutoff for screen.seqs | `95` |
| `uparse.min_size` | int | Min cluster size (filter singletons) | `2` |
| `uparse.identity` | float | OTU clustering identity threshold | `0.97` |

---

## Threading Model

OCToPUS uses Snakemake's DAG parallelism to maximally utilize available cores:

| Rule | Tool | Threads | Notes |
|------|------|---------|-------|
| 01 SPAdes | `spades.py -t` | `processors` | Fully parallel per sample |
| 05 align.seqs | mothur 1.48.0 `processors=` | 14 | RAM-limited: 1 at a time via `mem_mb` |
| 13 chimera.uchime | mothur 1.33.3 | 1 | Runs in parallel with 14 and 15 |
| 14 chimera.slayer | mothur 1.33.3 | 1 | Runs in parallel with 13 and 15 |
| 15 chimera.perseus | mothur 1.33.3 | 1 per sample | **93 samples in parallel** (new parallel design) |
| 23 usearch_global | usearch `-threads` | `processors` | Fully parallel |
| all others | — | 1–2 | Up to 14 samples run simultaneously |

**Example with 28 cores and 93 samples:**

- Per-sample rules 01–04, 06–10: up to 14 samples × 2 threads = 28 cores fully used
- Rule 05 align.seqs: 1 sample × 14 threads + 7 other samples × 2 threads = 28 cores
- Rule 15 Perseus: up to 28 samples processed simultaneously (1 thread each)
- Rules 16–22: single-threaded (CATCh/WEKA bottleneck)
- Rule 23 usearch_global: 28 threads

> **SILVA loading note:** `align.seqs` loads the SILVA database single-threaded (~3 min) before multi-threaded alignment begins. This is inherent to mothur's design and is not a bug.

---

## Bundled Tools

The following tools are included in `workflow/scripts/external/` and require no separate installation:

| Tool | Version | Path | Used by |
|------|---------|------|---------|
| mothur (modified) | 1.33.3 | `bin/mothur` | Rules 02–04, 06–09, 12–18 |
| uchime | — | `bin/uchime` | Rule 13 (via mothur) |
| BLAST formatdb | legacy | `bin/blast/bin/formatdb` | Rule 14 (chimera.slayer) |
| BLAST blastall | legacy | `bin/blast/bin/blastall` | Rule 14 (chimera.slayer) |
| BLAST megablast | legacy | `bin/blast/bin/megablast` | Rule 14 (chimera.slayer) |
| IPED_main.pl | 1.0 | `iped/IPED_main.pl` | Rule 10 |
| IPED.pl | 1.0 | `iped/IPED.pl` | Rule 10 |
| IPED.model | 1.0 | `iped/IPED.model` | Rule 10 |
| CATCh.pl | 1.0 | `catch/CATCh.pl` | Rule 16 |
| weka.jar | 3.7.11 | `catch/weka.jar` | Rules 10, 16 |
| weka_.jar | 3.7.11 | `catch/weka_.jar` | Rule 16 (denovo mode) |
| denovo.model | — | `catch/denovo.model` | Rule 16 |

> **mothur 1.33.3 is modified** — `pre.cluster` and `make.contigs` were patched by the original OCToPUS authors for IPED compatibility. The unmodified mothur 1.33.3 from bioconda will not work.
>
> **mothur 1.48.0** is installed via conda for rule 05 only (multi-threaded `align.seqs`).

---

## Portability — Moving to Another Machine

The pipeline is fully self-contained and portable across **Linux x86-64** machines.

### Transfer the pipeline

```bash
# On the source machine — exclude results and conda cache
rsync -av \
    --exclude 'results/' \
    --exclude '.snakemake/' \
    --exclude '*.log' \
    /path/to/OCTUPUS/ \
    user@newmachine:/path/to/OCTUPUS/

# Transfer SILVA reference separately (~3.4 GB) if needed
rsync -av data/silva.nr_v132.align user@newmachine:/path/to/data/
```

### Set up on the target machine

```bash
# 1. Install Miniconda if not present
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh

# 2. Create the conda environment from the pinned file
conda env create -f environment.yml
conda activate octopus

# 3. Run the setup wizard
bash setup.sh
# → answers questions about SILVA path, USEARCH, cores
# → writes config/config.yaml automatically

# 4. Validate
python workflow/scripts/validate_inputs.py config/config.yaml config/samples.tsv

# 5. Run — per-rule conda envs (SPAdes, mothur 1.48, Perl+Java) build on first execution
nohup snakemake --use-conda --cores N --resources mem_mb=14000 > run.log 2>&1 &
```

### What is portable vs. what needs manual transfer

| Item | Portable? | Notes |
|------|-----------|-------|
| Pipeline code | ✓ Yes | Everything in this repo |
| Conda environment | ✓ Yes | `environment.yml` recreates it exactly |
| Per-rule conda envs | ✓ Yes | Built automatically by Snakemake on first run |
| Bundled binaries | ✓ Yes | Linux x86-64 only |
| SILVA reference | Manual | ~3.4 GB — rsync or re-download |
| USEARCH binary | Manual | Re-download (free, user license) |
| Input FASTQ files | Manual | Your data |
| Results | Optional | Can re-run from scratch |

---

## Upstream Repository

This is a Snakemake modernization of the original OCToPUS pipeline by Mohamed Mysara et al.

| | |
|--|--|
| **Original code** | [github.com/M-Mysara/OCToPUS](https://github.com/M-Mysara/OCToPUS) |
| **Original paper** | Mysara et al. (2017) *GigaScience* [doi:10.1093/gigascience/gix017](https://doi.org/10.1093/gigascience/gix017) |
| **What changed** | Perl orchestration → Snakemake; per-rule conda envs; parallelism; pre-flight validation; parallel Perseus |
| **What is identical** | All algorithms, all tool versions, all parameters, all output formats |

---

## Citation

If you use this pipeline, please cite the original OCToPUS paper and the tools it uses:

- **OCToPUS:** Mysara, M., Njima, M., et al. (2017). From reads to operational taxonomic units: an ensemble processing pipeline for MiSeq amplicon sequencing data. *GigaScience*. [doi:10.1093/gigascience/gix017](https://doi.org/10.1093/gigascience/gix017)
- **IPED:** Mysara M, et al. (2016). IPED: Intra-Pair Elimination of Duplicates for error correction in paired-end sequencing. *BMC Bioinformatics* 17:192.
- **CATCh:** Mysara M, et al. (2015). CATCh, an Ensemble Classifier for Chimera Detection in 16S rRNA Sequencing Studies. *Appl. Environ. Microbiol.* 81:1573–84.
- **mothur:** Schloss PD, et al. (2009). Introducing mothur. *Appl. Environ. Microbiol.* 75:7537–41.
- **WEKA:** Hall M, et al. (2009). The WEKA data mining software. *SIGKDD Explorations* 11:10–18.
- **SPAdes:** Bankevich A, et al. (2012). SPAdes: A New Genome Assembly Algorithm. *J. Comput. Biol.* 19:455–77.
- **UPARSE:** Edgar RC. (2013). UPARSE: highly accurate OTU sequences from microbial amplicon reads. *Nat. Methods* 10:996–8.

---

## License

GNU General Public License v2.0. See [LICENSE](LICENSE).

Original OCToPUS authors: Mohamed Mysara et al., Belgian Nuclear Research Centre (SCK·CEN).
