rule chimera_uchime:
    input:
        fasta = f"{OUT}/cross_sample/12_mothur_unique_all/All.unique.fasta",
        names = f"{OUT}/cross_sample/12_mothur_unique_all/All.unique.names",
        group = f"{OUT}/cross_sample/11_merge/All.group"
    output:
        chimeras = f"{OUT}/cross_sample/13_chimera_uchime/All.unique.uchime.chimeras"
    log:
        f"{OUT}/logs/cross_sample/13_chimera_uchime.log"
    threads: 1
    params:
        outdir = f"{OUT}/cross_sample/13_chimera_uchime",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});chimera.uchime(fasta={input.fasta},name={input.names},group={input.group})" \
            >> {log} 2>&1
        """
