rule mothur_unique_all:
    input:
        fasta = f"results/{RUN}/cross_sample/11_merge/All.fasta",
        names = f"results/{RUN}/cross_sample/11_merge/All.names"
    output:
        fasta = temp(f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.fasta"),
        names = temp(f"results/{RUN}/cross_sample/12_mothur_unique_all/All.unique.names")
    log:
        f"results/{RUN}/logs/cross_sample/12_mothur_unique_all.log"
    params:
        outdir = f"results/{RUN}/cross_sample/12_mothur_unique_all",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});unique.seqs(fasta={input.fasta},name={input.names})" \
            >> {log} 2>&1
        # unique.seqs creates All.unique.fasta + All.names (named from fasta stem, not All.unique.names)
        mv {params.outdir}/All.names {output.names}
        """
