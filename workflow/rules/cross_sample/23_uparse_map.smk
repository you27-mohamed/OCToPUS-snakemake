rule uparse_global_map:
    input:
        sorted_fasta = f"{OUT}/cross_sample/21_uparse_sortbysize/All.uparse_sorted.fasta",
        otus         = f"{OUT}/cross_sample/22_uparse_cluster/All.uparse_sorted_otus.fasta"
    output:
        shared   = f"{OUT}/final/OCTOPUS.shared",
        biom     = f"{OUT}/final/OCTOPUS.biom",
        otutab   = f"{OUT}/final/OCTOPUS_otutab_txt",
        otus_out = f"{OUT}/final/OCTOPUS_OTUs.fasta",
        uc       = temp(f"{OUT}/cross_sample/23_uparse_map/All.uparse.mapping.uc")
    log:
        f"{OUT}/logs/cross_sample/23_uparse_map.log"
    threads: config["processors"]
    params:
        usearch  = config["usearch"],
        identity = config["uparse"]["identity"],
        outdir   = f"{OUT}/final"
    shell:
        """
        mkdir -p {params.outdir}

        {params.usearch} -usearch_global {input.sorted_fasta} \
            -db {input.otus} \
            -strand plus \
            -id {params.identity} \
            -threads {threads} \
            -mothur_shared_out {output.shared} \
            -otutabout {output.otutab} \
            -biomout {output.biom} \
            -uc {output.uc} \
            >> {log} 2>&1

        # Fix mothur shared file header (replace 'usearch' with OTU threshold)
        perl -pe 's/usearch/0.03/g' -i {output.shared}

        # Copy OTU sequences to final output
        cp {input.otus} {output.otus_out}
        """
