rule mothur_filter_seqs:
    input:
        align = "results/{run}/per_sample/{sample}/06_mothur_screen/{sample}.good.align"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/07_mothur_filter/{sample}.filter.fasta")
    log:
        "results/{run}/logs/per_sample/{sample}/07_mothur_filter.log"
    params:
        outdir = "results/{run}/per_sample/{sample}/07_mothur_filter",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});filter.seqs(fasta={input.align},vertical=T)" \
            >> {log} 2>&1
        # filter.seqs names output: {sample}.good.filter.fasta
        mv {params.outdir}/{wildcards.sample}.good.filter.fasta {output.fasta}
        """
