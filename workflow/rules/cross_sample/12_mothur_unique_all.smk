rule mothur_unique_all:
    input:
        fasta = f"{OUT}/cross_sample/11_merge/All.fasta",
        names = f"{OUT}/cross_sample/11_merge/All.names"
    output:
        fasta = temp(f"{OUT}/cross_sample/12_mothur_unique_all/All.unique.fasta"),
        names = temp(f"{OUT}/cross_sample/12_mothur_unique_all/All.unique.names")
    log:
        f"{OUT}/logs/cross_sample/12_mothur_unique_all.log"
    params:
        outdir = f"{OUT}/cross_sample/12_mothur_unique_all",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});unique.seqs(fasta={input.fasta},name={input.names})" \
            >> {log} 2>&1
        # unique.seqs creates All.unique.fasta + All.names (named from fasta stem, not All.unique.names)
        mv {params.outdir}/All.names {output.names}
        """
