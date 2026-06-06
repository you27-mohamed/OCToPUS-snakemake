rule mothur_unique_seqs_1:
    input:
        fasta = "results/{run}/per_sample/{sample}/03_mothur_qc/{sample}.trim.fasta"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/04_mothur_derep1/{sample}.unique.fasta"),
        names = temp("results/{run}/per_sample/{sample}/04_mothur_derep1/{sample}.names")
    log:
        "results/{run}/logs/per_sample/{sample}/04_mothur_derep1.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir = "results/{run}/per_sample/{sample}/04_mothur_derep1"
    shell:
        """
        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                unique.seqs(fasta={input.fasta})" \
            >> {log} 2>&1
        """
