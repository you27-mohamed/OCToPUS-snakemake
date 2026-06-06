rule merge_uparse:
    input:
        fastas = expand(
            f"results/{RUN}/cross_sample/19_uparse_format/{{sample}}.uparse.fasta",
            sample=SAMPLES
        )
    output:
        fasta = temp(f"results/{RUN}/cross_sample/20_merge_uparse/All.uparse.fasta")
    log:
        f"results/{RUN}/logs/cross_sample/20_merge_uparse.log"
    shell:
        """
        cat {input.fastas} > {output.fasta} 2>> {log}
        """
