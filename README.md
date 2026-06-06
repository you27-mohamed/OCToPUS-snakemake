# OCToPUS — Snakemake Pipeline

**Modernized 16S rRNA amplicon sequencing pipeline**

---

## What is OCToPUS

OCToPUS is an ensemble pipeline that combines SPAdes, mothur, IPED, CATCh/WEKA, and UPARSE to process MiSeq amplicon sequencing data. By chaining multiple independent error-correction and chimera-detection strategies, it achieves the lowest error rate and minimum spurious OTUs among comparable tools.

Originally published in:

> Mysara, M., Njima, M., et al. (2017). From reads to operational taxonomic units: an ensemble processing pipeline for MiSeq amplicon sequencing data. *GigaScience*.

This repository is a **Snakemake modernization** of the original pipeline — the same algorithms are used, with improved installation, error handling, and reproducibility.

---

## Requirements

- **Conda** (Miniconda or Anaconda)
- **Snakemake** >= 7.0
- **USEARCH 8.1.1861** — must be supplied by the user due to license restrictions. Download from http://www.drive5.com/usearch/
- **IPED and CATCh scripts** — must be extracted from the OCToPUS distribution. See `workflow/scripts/external/iped/README.md` and `workflow/scripts/external/catch/README.md` for instructions.

---

## Installation

```bash
# Install Snakemake
conda create -n snakemake -c bioconda -c conda-forge snakemake
conda activate snakemake

# Clone this repo
git clone https://github.com/YOUR_USERNAME/octopus-snakemake.git
cd octopus-snakemake

# Install bundled tool scripts (IPED, CATCh)
# See workflow/scripts/external/iped/README.md
# See workflow/scripts/external/catch/README.md
```

---

## Quick Start

```bash
# 1. Copy and edit config
cp config/config.yaml.example config/config.yaml
# Edit: set reference, usearch, samples paths, processors

# 2. Copy and edit samples sheet
cp config/samples.tsv.example config/samples.tsv
# Edit: add your SampleID + R1/R2 absolute paths

# 3. Dry run (preview pipeline without executing)
snakemake --use-conda --cores 8 --dry-run

# 4. Run
snakemake --use-conda --cores 8

# Resume after a crash (Snakemake resumes from last completed step automatically)
snakemake --use-conda --cores 8
```

---

## Configuration

All settings are controlled via `config/config.yaml`. The table below describes each key.

| Key | Description | Default |
|-----|-------------|---------|
| `run_id` | Output subfolder name under `results/` | Required |
| `samples` | Path to samples TSV file | Required |
| `reference` | Full path to SILVA reference FASTA | Required |
| `usearch` | Full path to USEARCH 8.1.1861 binary | Required |
| `processors` | CPU cores per tool invocation | Required |
| `mothur.maxambig` | Max ambiguous bases (trim.seqs) | 0 |
| `mothur.maxhomop` | Max homopolymer length (trim.seqs) | 8 |
| `mothur.minlength` | Min sequence length (trim.seqs) | 200 |
| `mothur.align_criteria` | Percentile cutoff for alignment screening | 95 |
| `uparse.min_size` | Min cluster size — singletons below discarded | 2 |
| `uparse.identity` | OTU clustering identity threshold | 0.97 |

---

## Output Files

Final outputs are written to `results/{run_id}/final/`:

| File | Description |
|------|-------------|
| `OCTOPUS_OTUs.fasta` | OTU representative sequences |
| `OCTOPUS.shared` | OTU abundance table (mothur format) |
| `OCTOPUS.biom` | OTU abundance table (BIOM format, QIIME-compatible) |
| `OCTOPUS_otutab_txt` | OTU abundance table (tab-separated, USEARCH format) |

Intermediate files per sample are written to `results/{run_id}/per_sample/{sample}/` (stages 01–10).
Cross-sample results are written to `results/{run_id}/cross_sample/` (stages 11–23).
Logs are written to `results/{run_id}/logs/`.

Intermediate files are automatically cleaned up after use (Snakemake `temp()`). Chimera detection results (stages 13–16) and IPED outputs (stage 10) are kept.

---

## Pipeline Stages

| Stage | Tool | Description |
|-------|------|-------------|
| 01 | SPAdes 3.5.0 | Pre-assembly error correction (BayesHammer) |
| 02 | mothur 1.33.3 | Paired-end assembly (make.contigs) |
| 03 | mothur | Quality filtering (trim.seqs) |
| 04 | mothur | 1st dereplication (unique.seqs) |
| 05 | mothur | Reference alignment (align.seqs, SILVA) |
| 06 | mothur | Alignment screening (screen.seqs) |
| 07 | mothur | Gap column removal (filter.seqs) |
| 08 | mothur | 2nd dereplication (unique.seqs) |
| 09 | mothur | Sequence list export (list.seqs) |
| 10 | IPED v1 | ML-based paired-end denoising |
| 11 | — | Merge all samples |
| 12 | mothur | Pre-chimera dereplication |
| 13–15 | mothur | Chimera detection (UCHIME, ChimeraSlayer, Perseus) |
| 16 | CATCh + WEKA | Ensemble chimera classifier (ML) |
| 17 | mothur | Remove chimeric sequences |
| 18 | mothur | Split back to per-sample |
| 19 | mothur + perl | Convert to UPARSE format |
| 20 | — | Merge UPARSE-format files |
| 21 | USEARCH | Sort by abundance, filter singletons |
| 22 | USEARCH | OTU clustering at 97% identity |
| 23 | USEARCH | Read mapping, generate output tables |

---

## Citation

If you use OCToPUS, please cite all included tools:

- **OCToPUS:** Mysara, M., Njima, M., et al. (2017). From reads to operational taxonomic units: an ensemble processing pipeline for MiSeq amplicon sequencing data. *GigaScience*.
- **IPED:** Mysara M, Leys N, Raes J, Monsieurs P. (2016). IPED: a highly efficient denoising tool for Illumina MiSeq Paired-end 16S rRNA gene amplicon sequencing data. *BMC Bioinformatics* 17:192.
- **CATCh:** Mysara M, Saeys Y, Leys N, Raes J, Monsieurs P. (2015). CATCh, an ensemble classifier for chimera detection in 16S rRNA sequencing studies. *Appl. Environ. Microbiol.* 81:1573–84.
- **mothur:** Schloss PD, et al. (2009). Introducing mothur. *Applied and Environmental Microbiology* 75:7537–41.
- **WEKA:** Hall M, et al. (2009). The WEKA Data Mining Software: An Update. *SIGKDD Explorations* 11:10–18.
- **SPAdes:** Bankevich A, et al. (2012). SPAdes: a new genome assembly algorithm. *J. Comput. Biol.* 19:455–77.
- **UPARSE:** Edgar RC. (2013). UPARSE: highly accurate OTU sequences from microbial amplicon reads. *Nat. Methods* 10:996–8.

---

## License

GNU General Public License v2.0. See LICENSE file.

Contact: mohamed.mysara@gmail.com
