rule mothur_trim_seqs:
    input:
        fasta = f"{OUT}/per_sample/{{sample}}/02_mothur_assemble/{{sample}}.trim.contigs.fasta"
    output:
        fasta = temp(f"{OUT}/per_sample/{{sample}}/03_mothur_qc/{{sample}}.trim.fasta")
    log:
        f"{OUT}/logs/per_sample/{{sample}}/03_mothur_qc.log"
    params:
        outdir   = f"{OUT}/per_sample/{{sample}}/03_mothur_qc",
        maxambig = config["mothur"]["maxambig"],
        maxhomop = config["mothur"]["maxhomop"],
        minlen   = config["mothur"]["minlength"],
        mothur   = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});trim.seqs(fasta={input.fasta},maxambig={params.maxambig},maxhomop={params.maxhomop},minlength={params.minlen})" \
            >> {log} 2>&1
        # trim.seqs names output after input stem: {{sample}}.trim.contigs.trim.fasta
        mv {params.outdir}/{wildcards.sample}.trim.contigs.trim.fasta {output.fasta}
        """
