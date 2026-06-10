rule mothur_make_contigs:
    input:
        r1 = f"{OUT}/per_sample/{{sample}}/01_spades/corrected_R1.fastq",
        r2 = f"{OUT}/per_sample/{{sample}}/01_spades/corrected_R2.fastq"
    output:
        fasta = temp(f"{OUT}/per_sample/{{sample}}/02_mothur_assemble/{{sample}}.trim.contigs.fasta"),
        qual  = temp(f"{OUT}/per_sample/{{sample}}/02_mothur_assemble/{{sample}}.contigs.qual")
    log:
        f"{OUT}/logs/per_sample/{{sample}}/02_mothur_assemble.log"
    params:
        outdir     = f"{OUT}/per_sample/{{sample}}/02_mothur_assemble",
        processors = config["processors"],
        mothur     = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});make.contigs(ffastq={input.r1},rfastq={input.r2},processors={params.processors})" \
            >> {log} 2>&1
        # mothur names output from input stem (corrected_R1.*) — rename to sample name
        mv {params.outdir}/corrected_R1.trim.contigs.fasta {output.fasta}
        mv {params.outdir}/corrected_R1.contigs.qual {output.qual}
        """
