rule mothur_align_seqs:
    input:
        fasta = "results/{run}/per_sample/{sample}/04_mothur_derep1/{sample}.unique.fasta"
    output:
        align = temp("results/{run}/per_sample/{sample}/05_mothur_align/{sample}.align")
    log:
        "results/{run}/logs/per_sample/{sample}/05_mothur_align.log"
    params:
        outdir     = "results/{run}/per_sample/{sample}/05_mothur_align",
        reference  = config["reference"],
        processors = config["processors"],
        mothur     = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});set.logfile(name={log},append=T);align.seqs(fasta={input.fasta},reference={params.reference},flip=T,processors={params.processors})" \
            >> {log} 2>&1
        """
