rule uparse_cluster_otus:
    input:
        fasta = f"{OUT}/cross_sample/21_uparse_sortbysize/All.uparse_sorted.fasta"
    output:
        otus = temp(f"{OUT}/cross_sample/22_uparse_cluster/All.uparse_sorted_otus.fasta")
    log:
        f"{OUT}/logs/cross_sample/22_uparse_cluster.log"
    params:
        usearch = config["usearch"]
    shell:
        """
        {params.usearch} -cluster_otus {input.fasta} \
            -otus {output.otus} \
            -relabel Otu \
            >> {log} 2>&1
        """
