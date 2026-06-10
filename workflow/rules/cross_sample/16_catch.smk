rule catch_ensemble:
    input:
        fasta   = f"{OUT}/cross_sample/11_merge/All.fasta",
        names   = f"{OUT}/cross_sample/11_merge/All.names",
        uchime  = f"{OUT}/cross_sample/13_chimera_uchime/All.unique.uchime.chimeras",
        slayer  = f"{OUT}/cross_sample/14_chimera_slayer/All.unique.slayer.chimeras",
        perseus = f"{OUT}/cross_sample/15_chimera_perseus/All.unique.perseus.chimeras"
    output:
        result = f"{OUT}/cross_sample/16_catch/CATCH_Result.arff.Final_Result"
    log:
        f"{OUT}/logs/cross_sample/16_catch.log"
    conda:
        "../../envs/perl.yaml"
    params:
        outdir    = f"{OUT}/cross_sample/16_catch",
        processors = config["processors"],
        catch_dir  = "workflow/scripts/external/catch"
    shell:
        """
        set -euo pipefail
        WORKDIR=$(pwd)

        # Absolute paths — CATCh uses getcwd() to locate weka_.jar and denovo.model
        FASTA="$WORKDIR/{input.fasta}"
        NAMES="$WORKDIR/{input.names}"
        UCHIME="$WORKDIR/{input.uchime}"
        SLAYER="$WORKDIR/{input.slayer}"
        PERSEUS="$WORKDIR/{input.perseus}"
        OUTDIR="$WORKDIR/{params.outdir}"
        LOGFILE="$WORKDIR/{log}"
        OUT_RESULT="$WORKDIR/{output.result}"

        mkdir -p "$OUTDIR"
        mkdir -p "$(dirname "$LOGFILE")"

        # Per-invocation temp dir for CATCh's getcwd()-based dependency resolution
        TMPRUN=$(mktemp -d)
        trap "rm -rf $TMPRUN" EXIT

        ln -s "$WORKDIR/{params.catch_dir}/CATCh.pl"     "$TMPRUN/CATCh.pl"
        ln -s "$WORKDIR/{params.catch_dir}/weka_.jar"    "$TMPRUN/weka_.jar"
        ln -s "$WORKDIR/{params.catch_dir}/denovo.model" "$TMPRUN/denovo.model"

        cd "$TMPRUN"
        perl CATCh.pl \
            _f "$FASTA" \
            _n "$NAMES" \
            _h "$OUTDIR" \
            _i All \
            _m d \
            _p {params.processors} \
            _y "$SLAYER" \
            _z "$PERSEUS" \
            _x "$UCHIME" \
            >> "$LOGFILE" 2>&1

        # CATCh writes its final result to outdir/All/Tools_Results/CATCH_Result.arff.Final_Result
        mv "$OUTDIR/All/Tools_Results/CATCH_Result.arff.Final_Result" "$OUT_RESULT"
        """
