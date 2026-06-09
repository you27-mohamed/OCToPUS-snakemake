rule chimera_slayer:
    input:
        fasta = f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.fasta",
        names = f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.names",
        group = f"results/{RUN}/cross_sample/11_merge/All.group"
    output:
        chimeras = f"results/{RUN}/cross_sample/14_chimera_slayer/All.unique.slayer.chimeras"
    log:
        f"results/{RUN}/logs/cross_sample/14_chimera_slayer.log"
    threads: 1
    params:
        outdir = f"results/{RUN}/cross_sample/14_chimera_slayer",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});chimera.slayer(fasta={input.fasta},name={input.names},group={input.group})" \
            >> {log} 2>&1
        """
