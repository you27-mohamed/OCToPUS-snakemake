rule uparse_sortbysize:
    input:
        fasta = f"results/{RUN}/cross_sample/20_merge_uparse/All.uparse.fasta"
    output:
        fasta = temp(f"results/{RUN}/cross_sample/21_uparse_sortbysize/All.uparse_sorted.fasta")
    log:
        f"results/{RUN}/logs/cross_sample/21_uparse_sortbysize.log"
    params:
        usearch  = config["usearch"],
        min_size = config["uparse"]["min_size"]
    shell:
        """
        {params.usearch} -sortbysize {input.fasta} \
            -fastaout {output.fasta} \
            -minsize {params.min_size} \
            >> {log} 2>&1
        """
