rule mothur_make_contigs:
    input:
        r1 = "results/{run}/per_sample/{sample}/01_spades/corrected_R1.fastq",
        r2 = "results/{run}/per_sample/{sample}/01_spades/corrected_R2.fastq"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/02_mothur_assemble/{sample}.trim.contigs.fasta"),
        qual  = temp("results/{run}/per_sample/{sample}/02_mothur_assemble/{sample}.contigs.qual")
    log:
        "results/{run}/logs/per_sample/{sample}/02_mothur_assemble.log"
    params:
        outdir     = "results/{run}/per_sample/{sample}/02_mothur_assemble",
        processors = config["processors"],
        mothur     = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});set.logfile(name={log},append=T);make.contigs(ffastq={input.r1},rfastq={input.r2},processors={params.processors})" \
            >> {log} 2>&1
        """
