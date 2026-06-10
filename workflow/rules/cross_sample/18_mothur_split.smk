rule mothur_split_groups:
    input:
        fasta = f"{OUT}/cross_sample/17_mothur_remove/All.pick.fasta",
        names = f"{OUT}/cross_sample/17_mothur_remove/All.pick.names",
        group = f"{OUT}/cross_sample/17_mothur_remove/All.pick.group"
    output:
        fastas = temp(expand(
            f"{OUT}/cross_sample/18_mothur_split/All.pick.{{sample}}.fasta",
            sample=SAMPLES
        )),
        names = temp(expand(
            f"{OUT}/cross_sample/18_mothur_split/All.pick.{{sample}}.names",
            sample=SAMPLES
        ))
    log:
        f"{OUT}/logs/cross_sample/18_mothur_split.log"
    params:
        outdir = f"{OUT}/cross_sample/18_mothur_split",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});set.logfile(name={log},append=T);split.groups(fasta={input.fasta},name={input.names},group={input.group})" \
            >> {log} 2>&1
        """
