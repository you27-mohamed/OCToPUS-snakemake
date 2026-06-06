rule mothur_unique_seqs_2:
    input:
        fasta = "results/{run}/per_sample/{sample}/07_mothur_filter/{sample}.filter.fasta",
        names = "results/{run}/per_sample/{sample}/06_mothur_screen/{sample}.good.names"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/08_mothur_derep2/{sample}.unique.fasta"),
        names = temp("results/{run}/per_sample/{sample}/08_mothur_derep2/{sample}.names")
    log:
        "results/{run}/logs/per_sample/{sample}/08_mothur_derep2.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir = "results/{run}/per_sample/{sample}/08_mothur_derep2"
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                unique.seqs(fasta={input.fasta},name={input.names})" \
            >> {log} 2>&1
        """
