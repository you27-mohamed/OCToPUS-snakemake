rule chimera_uchime:
    input:
        fasta = f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.fasta",
        names = f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.names",
        group = f"results/{RUN}/cross_sample/11_merge/All.group"
    output:
        chimeras = f"results/{RUN}/cross_sample/13_chimera_uchime/All.unique.uchime.chimeras"
    log:
        f"results/{RUN}/logs/cross_sample/13_chimera_uchime.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir     = f"results/{RUN}/cross_sample/13_chimera_uchime",
        processors = config["processors"]
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                chimera.uchime(fasta={input.fasta},name={input.names},group={input.group},processors={params.processors})" \
            >> {log} 2>&1
        """
