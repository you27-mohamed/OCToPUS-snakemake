rule mothur_list_seqs:
    input:
        names = "results/{run}/per_sample/{sample}/08_mothur_derep2/{sample}.names"
    output:
        accnos = temp("results/{run}/per_sample/{sample}/09_mothur_listseqs/{sample}.accnos")
    log:
        "results/{run}/logs/per_sample/{sample}/09_mothur_listseqs.log"
    params:
        outdir = "results/{run}/per_sample/{sample}/09_mothur_listseqs",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});list.seqs(name={input.names})" \
            >> {log} 2>&1
        # list.seqs names output after names stem: {sample}.accnos — matches output directly
        """
