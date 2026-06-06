rule mothur_list_seqs:
    input:
        names = "results/{run}/per_sample/{sample}/08_mothur_derep2/{sample}.names"
    output:
        accnos = temp("results/{run}/per_sample/{sample}/09_mothur_listseqs/{sample}.accnos")
    log:
        "results/{run}/logs/per_sample/{sample}/09_mothur_listseqs.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir = "results/{run}/per_sample/{sample}/09_mothur_listseqs"
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                list.seqs(name={input.names})" \
            >> {log} 2>&1
        """
