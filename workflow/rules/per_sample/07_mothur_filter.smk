rule mothur_filter_seqs:
    input:
        align = "results/{run}/per_sample/{sample}/06_mothur_screen/{sample}.good.align"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/07_mothur_filter/{sample}.filter.fasta")
    log:
        "results/{run}/logs/per_sample/{sample}/07_mothur_filter.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir = "results/{run}/per_sample/{sample}/07_mothur_filter"
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                filter.seqs(fasta={input.align},vertical=T)" \
            >> {log} 2>&1
        """
