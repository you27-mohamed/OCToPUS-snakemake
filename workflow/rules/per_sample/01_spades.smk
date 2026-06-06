rule spades_correct:
    input:
        r1 = lambda wc: samples_df.loc[samples_df["sample"] == wc.sample, "r1"].values[0],
        r2 = lambda wc: samples_df.loc[samples_df["sample"] == wc.sample, "r2"].values[0]
    output:
        r1 = temp("results/{run}/per_sample/{sample}/01_spades/corrected_R1.fastq"),
        r2 = temp("results/{run}/per_sample/{sample}/01_spades/corrected_R2.fastq")
    log:
        "results/{run}/logs/per_sample/{sample}/01_spades.log"
    conda:
        "../../envs/spades.yaml"
    params:
        outdir = "results/{run}/per_sample/{sample}/01_spades",
        processors = config["processors"]
    shell:
        """
        spades.py --only-error-correction \
            -1 {input.r1} -2 {input.r2} \
            -o {params.outdir} \
            -t {params.processors} \
            >> {log} 2>&1

        # Decompress corrected reads
        gunzip {params.outdir}/corrected/*.gz >> {log} 2>&1

        # Move to standard output names
        r1_cor=$(ls {params.outdir}/corrected/*R1*.fastq 2>/dev/null || \
                 ls {params.outdir}/corrected/*_1*.fastq 2>/dev/null | head -1)
        r2_cor=$(ls {params.outdir}/corrected/*R2*.fastq 2>/dev/null || \
                 ls {params.outdir}/corrected/*_2*.fastq 2>/dev/null | head -1)
        mv "$r1_cor" {output.r1}
        mv "$r2_cor" {output.r2}
        """
