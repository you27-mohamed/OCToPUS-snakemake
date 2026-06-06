rule mothur_trim_seqs:
    input:
        fasta = "results/{run}/per_sample/{sample}/02_mothur_assemble/{sample}.trim.contigs.fasta"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/03_mothur_qc/{sample}.trim.fasta")
    log:
        "results/{run}/logs/per_sample/{sample}/03_mothur_qc.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir   = "results/{run}/per_sample/{sample}/03_mothur_qc",
        maxambig = config["mothur"]["maxambig"],
        maxhomop = config["mothur"]["maxhomop"],
        minlen   = config["mothur"]["minlength"]
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                trim.seqs(fasta={input.fasta},maxambig={params.maxambig},maxhomop={params.maxhomop},minlength={params.minlen})" \
            >> {log} 2>&1
        """
