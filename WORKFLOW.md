# OCToPUS — Workflow Topology

**Full name:** Optimized CATCh, mothur, IPED, UPARSE and SPAdes
**Reference:** Mysara, M., Njima, M., et al., 2017. *GigaScience.*
**Orchestrator:** [`Source_code.pl`](Source_code.pl)

---

## Pipeline Overview

```
╔══════════════════════════════════════════════════════════════════════════════════════════╗
║                         OCToPUS — 16S rRNA Amplicon Sequencing Pipeline                  ║
║              Optimized CATCh, mothur, IPED, UPARSE, SPAdes  (Mysara et al. 2017)        ║
╚══════════════════════════════════════════════════════════════════════════════════════════╝

  ┌─────────────────────────────── INPUTS ──────────────────────────────────┐
  │                                                                          │
  │  stability.file          SILVA reference DB        USEARCH executable    │
  │  (TSV: SampleID,         silva.bacteria.fasta      usearch8.1.1861      │
  │   R1.fastq, R2.fastq)    (mothur-compatible)       (user-supplied)       │
  └────────┬─────────────────────────┬────────────────────────┬─────────────┘
           │                         │                        │
           ▼                         │                        │
  ╔════════════════════╗             │                        │
  ║  Parse stability   ║             │                        │
  ║  file → loop each  ║             │                        │
  ║  sample            ║             │                        │
  ╚═════════╤══════════╝             │                        │
            │                        │                        │
            │  ┌─────────────────────────────────────────────────────────────────┐
            │  │      PER-SAMPLE PROCESSING  (repeated for each sample)          │
            │  └─────────────────────────────────────────────────────────────────┘
            │
            ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 1 ▸ SPAdes 3.5.0  (BayesHammer error correction only)           │
  │                                                                          │
  │  Input : Sample_R1.fastq  +  Sample_R2.fastq  (raw paired-end reads)   │
  │  Cmd   : spades.py --only-error-correction -1 R1 -2 R2 -o output/      │
  │  Output: corrected/Sample_R1.00.0_0.cor.fastq.gz                        │
  │          corrected/Sample_R2.00.0_0.cor.fastq.gz                        │
  │          → gunzip both → .cor.fastq (uncompressed)                      │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │ corrected R1 + R2 fastq
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 2 ▸ mothur 1.33.3  (assembly + QC chain)                        │
  │                                                                          │
  │  ① make.contigs(ffastq=R1cor, rfastq=R2cor)                            │
  │     → .trim.contigs.fasta  (assembled amplicons)                        │
  │     → .contigs.qual        (IPED-format quality scores)                 │
  │                                                                          │
  │  ② trim.seqs(maxambig=0, maxhomop=8, minlength=200)                    │
  │     → .trim.fasta          (quality-filtered sequences)                 │
  │                                                                          │
  │  ③ unique.seqs             (1st dereplication)                          │
  │     → .unique.fasta  +  .names                                          │
  │                                                                          │
  │  ④ align.seqs(reference=SILVA, flip=T)                                  │
  │     → .align               (MSA against reference)                      │
  │                                                                          │
  │  ⑤ screen.seqs(optimize=start-end-length, criteria=95)                 │
  │     → .good.align  +  .good.names  (95th-percentile alignment filter)   │
  │                                                                          │
  │  ⑥ filter.seqs(vertical=T)                                              │
  │     → .filter.fasta        (remove gap-only columns from alignment)     │
  │                                                                          │
  │  ⑦ unique.seqs             (2nd dereplication post-filter)              │
  │     → .unique.fasta  +  .names                                          │
  │                                                                          │
  │  ⑧ list.seqs               (export accession list)                      │
  │     → .accnos                                                            │
  └───────────────┬──────────────────────────────┬──────────────────────────┘
                  │ .fasta + .names               │ .contigs.qual + .accnos
                  ▼                               ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 3 ▸ IPED v1  (Illumina Paired-End Denoising)                    │
  │                                                                          │
  │  Input : .unique.fasta, .names (mothur)                                  │
  │          .contigs.qual (IPED-format quality), .accnos (seq list)        │
  │  Cmd   : perl IPED_main.pl _n names _f fasta _c qual_contig             │
  │                             _q qual _p procs _o output _i SampleID      │
  │                                                                          │
  │  Process: ML-based base-call error correction using quality scores      │
  │           → probabilistic denoising of sequencing errors                │
  │                                                                          │
  │  Output: IPED_Final/SampleID/Results.IPED.fasta   (denoised seqs)      │
  │          IPED_Final/SampleID/Results.IPED.names   (abundance map)       │
  │          IPED_Final/SampleID/Results.IPED.groups  (sample label)        │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │  (accumulate per sample into cat lists)
            ╔══════════════════════╧═══════════════════════╗
            ║  END OF PER-SAMPLE LOOP                       ║
            ║  All samples now have IPED fasta/names/groups ║
            ╚══════════════════════╤═══════════════════════╝
                                   │
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 4 ▸ Merge All Samples                                            │
  │                                                                          │
  │  cat Sample1.IPED.fasta  Sample2.IPED.fasta  ... → All.fasta           │
  │  cat Sample1.IPED.names  Sample2.IPED.names  ... → All.names           │
  │  cat Sample1.groups      Sample2.groups       ... → All.group           │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │ All.fasta  All.names  All.group
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 5 ▸ CATCh v1  (ensemble chimera detection)                      │
  │                                                                          │
  │  Pre-step: mothur unique.seqs(All.fasta, All.names)                    │
  │            → All.unique.fasta + All.unique.names                        │
  │                                                                          │
  │  Three independent chimera detectors run in parallel:                   │
  │                                                                          │
  │   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐ │
  │   │ mothur           │  │ mothur           │  │ mothur               │ │
  │   │ chimera.uchime   │  │ chimera.slayer   │  │ chimera.perseus      │ │
  │   │ (UCHIME algo)    │  │ (ChimeraSlayer)  │  │ (Perseus algo)       │ │
  │   └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘ │
  │            │                     │                        │             │
  │   .uchime.chimeras       .slayer.chimeras        .perseus.chimeras      │
  │            │                     │                        │             │
  │            └─────────────────────┴────────────────────────┘             │
  │                                  │                                      │
  │                                  ▼                                      │
  │   ┌──────────────────────────────────────────────────────────────────┐  │
  │   │  CATCh.pl  +  WEKA 3.7.11  (ML ensemble classifier)             │  │
  │   │  Combines votes from 3 detectors using trained model             │  │
  │   │  → CATCH_Result.arff.Final_Result  (chimeric / non-chimeric)    │  │
  │   └──────────────────────────────────────────────────────────────────┘  │
  │                                                                          │
  │  mothur remove.seqs(accnos=chimeric_IDs)                                │
  │     → All.pick.fasta  +  All.pick.names  +  All.pick.group              │
  │  mothur split.groups → All.pick.SampleN.fasta per sample                │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │ chimera-free per-sample fastas
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 6 ▸ UPARSE format preparation                                   │
  │                                                                          │
  │  For each sample:                                                        │
  │    mothur sort.seqs(fasta, name)                                         │
  │    → .sorted.fasta  +  .sorted.names                                    │
  │    perl mothur2uparse.pl fasta names abundance SampleID                 │
  │    → .uparse.fasta  (USEARCH-formatted: "seqID;size=N;sample=S")       │
  │                                                                          │
  │  cat Sample1.uparse.fasta Sample2.uparse.fasta ... → All.uparse.fasta  │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │ All.uparse.fasta
                                   ▼
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  STAGE 7 ▸ UPARSE / USEARCH 8.1.1861  (OTU clustering)                │
  │                                                                          │
  │  ① usearch -sortbysize  (minsize=2, filter singletons)                 │
  │     → All.uparse_sorted.fasta                                           │
  │                                                                          │
  │  ② usearch -cluster_otus  (97% similarity, greedy clustering)           │
  │     → All.uparse_sorted_otus.fasta  (OTU representative seqs)          │
  │       labeled: Otu1, Otu2, Otu3, ...                                    │
  │                                                                          │
  │  ③ usearch -usearch_global  (map all reads → OTUs at 97% identity)     │
  │     -strand plus  -id 0.97                                              │
  │     → OCTOPUS.shared      (mothur-format OTU table)                    │
  │     → OCTOPUS_otutab_txt  (tab-separated OTU table)                    │
  │     → OCTOPUS.biom        (BIOM-format OTU table)                      │
  │     → All.uparse.mapping  (per-read assignment map .uc)                │
  │                                                                          │
  │  cp OTU seqs → OCTOPUS_OTUs.fasta                                       │
  └────────────────────────────────┬────────────────────────────────────────┘
                                   │
                                   ▼
  ┌─────────────────────────────────────── FINAL OUTPUTS ───────────────────┐
  │                                                                          │
  │   OCTOPUS_OTUs.fasta        OTU representative sequences (FASTA)        │
  │                                                                          │
  │   OCTOPUS.shared            OTU abundance table → mothur downstream     │
  │                                                                          │
  │   OCTOPUS.biom              OTU abundance table → QIIME downstream      │
  │                                                                          │
  │   OCTOPUS_otutab_txt        OTU abundance table → USEARCH downstream    │
  │                                                                          │
  └──────────────────────────────────────────────────────────────────────────┘
```

---

## Stage-by-Stage Code Reference

All stages are orchestrated by a single Perl script: **[`Source_code.pl`](Source_code.pl)**

### Input parsing & initialization
**File:** [`Source_code.pl:26–49`](Source_code.pl#L26)

Parses CLI options (`_f`, `_r`, `_o`, `_p`, `_u`, `_i`) using a custom underscore-prefix loop (avoids clash with compression tool flags). Validates all mandatory inputs, creates output directory `$output/$logfile/`.

```perl
# Source_code.pl:30-35 — custom option parser
foreach my $value(@options){
    for(my $a=0;$a<32;$a=$a+2){
        my $temp_Value = '_'.$value;
        if($temp_Value eq $ARGV[$a]){$opts{$value}=$ARGV[$a+1];}
    }
}
```

---

### Stage 1 — SPAdes error correction
**File:** [`Source_code.pl:68–74`](Source_code.pl#L68)

Runs SPAdes in `--only-error-correction` mode (BayesHammer), then decompresses output `.cor.fastq.gz` files and re-derives corrected file paths via regex substitution.

```perl
# Source_code.pl:69
system "./SPAdes\-3\.5\.0\-Linux/bin/spades.py --only-error-correction -1 $forward -2 $reverse -o $output > $log 2>&1 >>$log";

# Source_code.pl:71-74 — path rewriting after SPAdes
$forward = basename($forward); $forward=$output."/corrected/".$forward;
$forward=~s/\.fastq/.00.0_0.cor.fastq.gz/;
system("gunzip $forward"); system("gunzip $reverse");
$forward=~s/\.gz//; $reverse=~s/\.gz//;
```

---

### Stage 2 — mothur assembly + QC chain
**File:** [`Source_code.pl:78–83`](Source_code.pl#L78)

Single `system` call invoking 8 chained mothur commands in one quoted batch. Intermediate file paths are derived from the corrected forward-read path via regex substitutions.

```perl
# Source_code.pl:79
system "./mothur \"#set.dir(output=$output);set.logfile(name=$sample.logfile,append=T);
  make.contigs(ffastq=$forward,rfastq=$reverse,processors=$processors);
  trim.seqs(fasta=current, maxambig=0, maxhomop=8, minlength=200);
  unique.seqs(fasta=current);
  align.seqs(fasta=current, reference=$reference, flip=T);
  screen.seqs(fasta=current, name=current, optimize=start-end-length, criteria=95);
  filter.seqs(fasta=current, vertical=T);
  unique.seqs(fasta=current, name=current);
  list.seqs(name=current)\" > log";

# Source_code.pl:81-83 — output path derivation
my $fasta=$forward; $fasta=~s/.fastq/.trim.contigs.trim.unique.good.filter.unique.fasta/;
my $name=$forward;  $name=~s/.fastq/.trim.contigs.trim.unique.good.filter.names/;
my $list=$forward;  $list=~s/.fastq/.trim.contigs.trim.unique.good.filter.accnos/;
```

---

### Stage 3 — IPED denoising
**File:** [`Source_code.pl:86–96`](Source_code.pl#L86)

Calls external `IPED_main.pl` (bundled). After IPED, creates a `.groups` file by prepending the sample label to each accession line via an inline Perl one-liner.

```perl
# Source_code.pl:87
system "perl ./IPED_main.pl _n $name _f $fasta _c $contig _q $qual _p $processors _o $output _i $sample >>$log";

# Source_code.pl:89-96 — collect IPED outputs per sample
my $fasta=$output."/IPED_Final/".$sample."/Results.IPED.fasta";
my $name=$output."/IPED_Final/".$sample."/Results.IPED.names";
my $group=$output."/IPED_Final/".$sample."/Results.IPED.groups";
system("perl -pe \"s/^([\\w\\W]+)\\n/\$1\\t$sample\\n/g\" $list > $group");
$command1=$command1."$fasta ";   # accumulate for later cat
$command2=$command2."$name ";
$command3=$command3."$group ";
push(@groups,$sample);
```

---

### Stage 4 — Merge all samples
**File:** [`Source_code.pl:99–105`](Source_code.pl#L99)

Executes the three `cat` commands built up during the per-sample loop.

```perl
# Source_code.pl:103-105
$command1=$command1."> ".$output."/All.fasta"; system $command1;
$command2=$command2."> ".$output."/All.names"; system $command2;
$command3=$command3."> ".$output."/All.group"; system $command3;
```

---

### Stage 5 — CATCh ensemble chimera detection
**File:** [`Source_code.pl:106–120`](Source_code.pl#L106)

Three chimera detectors run sequentially inside a single mothur call, then `CATCh.pl` (backed by WEKA) merges their outputs. Chimeric sequences removed via `remove.seqs` + `split.groups`.

```perl
# Source_code.pl:108 — run all 3 detectors
system "./mothur \"#set.dir(output=$output);...
  unique.seqs(fasta=$fasta,name=$name);
  chimera.uchime(fasta=current,name=current,group=$group,processors=$processors);
  chimera.slayer(fasta=current,name=current,group=current,processors=$processors);
  chimera.perseus(fasta=current,name=current,group=current,processors=$processors)\" > $log 2>&1";

# Source_code.pl:115 — CATCh ML ensemble
system "perl CATCh.pl _f $fasta _n $name _h $output _i All _m d _p $processors _y $slayer _z $perseus _x $uchime >>$log";

# Source_code.pl:118-120 — remove chimeras + split back to per-sample
system "echo \"CATCh_Chimera_Check\" >accnos";
system "grep -P \"\tChimeric\" $accnos | cut -f1 >> accnos";
system "./mothur \"#...remove.seqs(...);split.groups(...)\" >> $log";
```

---

### Stage 6 — UPARSE format conversion
**File:** [`Source_code.pl:122–135`](Source_code.pl#L122)

Per-sample loop: sort sequences by abundance, convert mothur `.names` format to USEARCH `size=N` header convention via `mothur2uparse.pl`, then cat all samples into one file.

```perl
# Source_code.pl:127-132
system "./mothur \"#...sort.seqs(fasta=$fasta,name=$name)\" >> $log";
my $fasta_uparse=$output."/All.pick.".$sample.".uparse.fasta";
system "perl mothur2uparse.pl $fasta $name a $sample > $fasta_uparse";
$command=$command."$fasta_uparse ";

# Source_code.pl:134-135
my $fasta_uparse=$output."/All.uparse.fasta";
system $command." > $fasta_uparse";
```

---

### Stage 7 — UPARSE OTU clustering
**File:** [`Source_code.pl:138–151`](Source_code.pl#L138)

Three sequential USEARCH calls: filter singletons → cluster OTUs at 97% → global alignment map to produce all output table formats.

```perl
# Source_code.pl:141 — remove singletons
system "$u -sortbysize $fasta_uparse -fastaout $fasta_uparse_sort -minsize 2 >>$log 2>&1";

# Source_code.pl:144 — cluster OTUs
system "$u -cluster_otus $fasta_uparse_sort -otus $fasta_uparse_sort_otus -relabel Otu >>$log 2>&1";

# Source_code.pl:149 — map reads → OTUs, emit all table formats
system("$u -usearch_global $fasta_uparse_sort -db $fasta_uparse_sort_otus -strand plus -id 0.97
    -mothur_shared_out $mothur_shared -otutabout $otutab_txt -biomout $otutab_biom -uc $map_uc >>$log 2>&1");

# Source_code.pl:150 — fix mothur shared file header
system("perl -pe \"s/usearch/0.03/g\" -i $mothur_shared");
```

---

## Tool Dependency Summary

| Tool | Role | Scope | Language |
|------|------|-------|----------|
| `Source_code.pl` | Pipeline orchestrator | All stages | Perl |
| `SPAdes 3.5.0` | Pre-assembly error correction | Stage 1 | Python |
| `mothur 1.33.3`* | Assembly, QC, chimera detection, filtering | Stage 2, 5, 6 | Binary |
| `IPED_main.pl`* | ML-based paired-end denoising | Stage 3 | Perl |
| `CATCh.pl` + `WEKA 3.7.11`* | Ensemble chimera classifier | Stage 5 | Perl + Java |
| `mothur2uparse.pl` | Format bridge mothur → USEARCH | Stage 6 | Perl |
| `usearch 8.1.1861` | OTU clustering + read mapping | Stage 7 | Binary (ext) |

\* Modified from upstream to remove redundant steps and increase inter-tool compatibility.

---

## Key Architectural Notes

- **Error correction before assembly** — SPAdes BayesHammer runs on raw reads *before* `make.contigs`, reducing indel/substitution errors entering the assembly step (`Source_code.pl:69`).
- **Double dereplication** — `unique.seqs` called twice: before alignment (reduce compute load) and again after `filter.seqs` (gap removal can create new duplicate sequences) (`Source_code.pl:79`).
- **Ensemble chimera detection** — CATCh combines votes from UCHIME + ChimeraSlayer + Perseus via a WEKA-trained ML model rather than trusting any single algorithm (`Source_code.pl:108–115`).
- **Singleton removal** — `minsize=2` in USEARCH discards all sequences appearing only once before OTU clustering, a standard noise-reduction step (`Source_code.pl:141`).
- **Format bridge** — `mothur2uparse.pl` converts mothur's tab-separated `.names` abundance representation to USEARCH's `size=N` inline header format (`Source_code.pl:131`).
- **Output compatibility** — final USEARCH global-map step emits three table formats simultaneously (mothur `.shared`, BIOM, tab-separated) for downstream tool flexibility (`Source_code.pl:149`).
