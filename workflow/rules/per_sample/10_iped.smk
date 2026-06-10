rule iped_denoise:
    input:
        fasta  = f"{OUT}/per_sample/{{sample}}/08_mothur_derep2/{{sample}}.unique.fasta",
        names  = f"{OUT}/per_sample/{{sample}}/08_mothur_derep2/{{sample}}.names",
        contig = f"{OUT}/per_sample/{{sample}}/02_mothur_assemble/{{sample}}.trim.contigs.fasta",
        qual   = f"{OUT}/per_sample/{{sample}}/02_mothur_assemble/{{sample}}.contigs.qual",
        accnos = f"{OUT}/per_sample/{{sample}}/09_mothur_listseqs/{{sample}}.accnos"
    output:
        fasta  = f"{OUT}/per_sample/{{sample}}/10_iped/{{sample}}.IPED.fasta",
        names  = f"{OUT}/per_sample/{{sample}}/10_iped/{{sample}}.IPED.names",
        groups = f"{OUT}/per_sample/{{sample}}/10_iped/{{sample}}.IPED.groups"
    log:
        f"{OUT}/logs/per_sample/{{sample}}/10_iped.log"
    conda:
        "../../envs/perl.yaml"
    params:
        outdir     = f"{OUT}/per_sample/{{sample}}/10_iped",
        processors = config["processors"],
        iped_dir   = "workflow/scripts/external/iped",
        catch_dir  = "workflow/scripts/external/catch",
        bin_dir    = "workflow/scripts/external/bin"
    shell:
        """
        set -euo pipefail
        WORKDIR=$(pwd)

        # realpath -m resolves both relative and absolute paths correctly
        FASTA=$(realpath -m "{input.fasta}")
        NAMES=$(realpath -m "{input.names}")
        CONTIG=$(realpath -m "{input.contig}")
        QUAL=$(realpath -m "{input.qual}")
        ACCNOS=$(realpath -m "{input.accnos}")
        OUTDIR=$(realpath -m "{params.outdir}")
        LOGFILE=$(realpath -m "{log}")
        OUT_FASTA=$(realpath -m "{output.fasta}")
        OUT_NAMES=$(realpath -m "{output.names}")
        OUT_GROUPS=$(realpath -m "{output.groups}")

        mkdir -p "$OUTDIR"
        mkdir -p "$(dirname "$LOGFILE")"

        # Per-invocation temp dir — avoids Temp/ and temp_split/ collisions across parallel samples
        TMPRUN=$(mktemp -d)
        trap "rm -rf $TMPRUN" EXIT

        ln -s "$WORKDIR/{params.iped_dir}/IPED_main.pl" "$TMPRUN/IPED_main.pl"
        ln -s "$WORKDIR/{params.iped_dir}/IPED.pl"      "$TMPRUN/IPED.pl"
        ln -s "$WORKDIR/{params.iped_dir}/IPED.model"   "$TMPRUN/IPED.model"
        ln -s "$WORKDIR/{params.bin_dir}/mothur"        "$TMPRUN/mothur"
        ln -s "$WORKDIR/{params.catch_dir}/weka.jar"    "$TMPRUN/weka.jar"

        cd "$TMPRUN"
        # _o must end with '/' — IPED concatenates opts{{o}}.'IPED_Final/' without separator
        perl IPED_main.pl \
            _n "$NAMES" \
            _f "$FASTA" \
            _c "$CONTIG" \
            _q "$QUAL" \
            _p {params.processors} \
            _o "$OUTDIR/" \
            _i {wildcards.sample} \
            >> "$LOGFILE" 2>&1

        # Move IPED outputs to Snakemake-tracked paths
        mv "$OUTDIR/IPED_Final/{wildcards.sample}/Results.IPED.fasta" "$OUT_FASTA"
        mv "$OUTDIR/IPED_Final/{wildcards.sample}/Results.IPED.names" "$OUT_NAMES"

        # Build groups file: each accession gets the sample label as group
        perl -pe 's/^(\\S+).*/$1\\t{wildcards.sample}\\n/g' "$ACCNOS" > "$OUT_GROUPS" 2>> "$LOGFILE"
        """
