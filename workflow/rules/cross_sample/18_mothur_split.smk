rule mothur_split_groups:
    input:
        fasta = f"results/{RUN}/cross_sample/17_mothur_remove/All.pick.fasta",
        names = f"results/{RUN}/cross_sample/17_mothur_remove/All.pick.names",
        group = f"results/{RUN}/cross_sample/17_mothur_remove/All.pick.group"
    output:
        fastas = temp(expand(
            f"results/{RUN}/cross_sample/18_mothur_split/All.pick.{{sample}}.fasta",
            sample=SAMPLES
        ))
    log:
        f"results/{RUN}/logs/cross_sample/18_mothur_split.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir = f"results/{RUN}/cross_sample/18_mothur_split"
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                split.groups(fasta={input.fasta},name={input.names},group={input.group})" \
            >> {log} 2>&1
        """
