rule mothur_unique_seqs_1:
    input:
        fasta = "results/{run}/per_sample/{sample}/03_mothur_qc/{sample}.trim.fasta"
    output:
        fasta = temp("results/{run}/per_sample/{sample}/04_mothur_derep1/{sample}.unique.fasta"),
        names = temp("results/{run}/per_sample/{sample}/04_mothur_derep1/{sample}.names")
    log:
        "results/{run}/logs/per_sample/{sample}/04_mothur_derep1.log"
    params:
        outdir = "results/{run}/per_sample/{sample}/04_mothur_derep1",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});unique.seqs(fasta={input.fasta})" \
            >> {log} 2>&1
        # unique.seqs names output after input stem: {sample}.trim.unique.fasta, {sample}.trim.names
        mv {params.outdir}/{wildcards.sample}.trim.unique.fasta {output.fasta}
        mv {params.outdir}/{wildcards.sample}.trim.names {output.names}
        """
