rule mothur_unique_seqs_2:
    input:
        fasta = f"{OUT}/per_sample/{{sample}}/07_mothur_filter/{{sample}}.filter.fasta",
        names = f"{OUT}/per_sample/{{sample}}/06_mothur_screen/{{sample}}.good.names"
    output:
        fasta = temp(f"{OUT}/per_sample/{{sample}}/08_mothur_derep2/{{sample}}.unique.fasta"),
        names = temp(f"{OUT}/per_sample/{{sample}}/08_mothur_derep2/{{sample}}.names")
    log:
        f"{OUT}/logs/per_sample/{{sample}}/08_mothur_derep2.log"
    params:
        outdir = f"{OUT}/per_sample/{{sample}}/08_mothur_derep2",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});unique.seqs(fasta={input.fasta},name={input.names})" \
            >> {log} 2>&1
        # unique.seqs names output after fasta stem: {{sample}}.filter.unique.fasta, {{sample}}.filter.names
        mv {params.outdir}/{wildcards.sample}.filter.unique.fasta {output.fasta}
        mv {params.outdir}/{wildcards.sample}.filter.names {output.names}
        """
