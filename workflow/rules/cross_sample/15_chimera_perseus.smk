rule chimera_perseus:
    input:
        fasta = f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.fasta",
        names = f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.names",
        group = f"results/{RUN}/cross_sample/11_merge/All.group"
    output:
        chimeras = f"results/{RUN}/cross_sample/15_chimera_perseus/All.unique.perseus.chimeras"
    log:
        f"results/{RUN}/logs/cross_sample/15_chimera_perseus.log"
    params:
        outdir     = f"results/{RUN}/cross_sample/15_chimera_perseus",
        processors = config["processors"],
        mothur     = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});set.logfile(name={log},append=T);chimera.perseus(fasta={input.fasta},name={input.names},group={input.group},processors={params.processors})" \
            >> {log} 2>&1
        """
