rule mothur_align_seqs:
    input:
        fasta = f"{OUT}/per_sample/{{sample}}/04_mothur_derep1/{{sample}}.unique.fasta"
    output:
        align = temp(f"{OUT}/per_sample/{{sample}}/05_mothur_align/{{sample}}.align")
    log:
        f"{OUT}/logs/per_sample/{{sample}}/05_mothur_align.log"
    conda:
        "../../envs/mothur_threaded.yaml"
    threads: 14
    resources:
        mem_mb = 14000
    params:
        outdir    = f"{OUT}/per_sample/{{sample}}/05_mothur_align",
        reference = config["reference"]
    shell:
        """
        mkdir -p {params.outdir}
        mothur "#set.dir(output={params.outdir});align.seqs(fasta={input.fasta},reference={params.reference},flip=T,processors={threads})" \
            >> {log} 2>&1
        # align.seqs names output after input stem: {{sample}}.unique.align
        mv {params.outdir}/{wildcards.sample}.unique.align {output.align}
        """
