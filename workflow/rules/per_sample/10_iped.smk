IPED_SCRIPT = "workflow/scripts/external/iped/IPED_main.pl"

rule iped_denoise:
    input:
        fasta  = "results/{run}/per_sample/{sample}/08_mothur_derep2/{sample}.unique.fasta",
        names  = "results/{run}/per_sample/{sample}/08_mothur_derep2/{sample}.names",
        contig = "results/{run}/per_sample/{sample}/02_mothur_assemble/{sample}.trim.contigs.fasta",
        qual   = "results/{run}/per_sample/{sample}/02_mothur_assemble/{sample}.contigs.qual",
        accnos = "results/{run}/per_sample/{sample}/09_mothur_listseqs/{sample}.accnos"
    output:
        fasta  = "results/{run}/per_sample/{sample}/10_iped/{sample}.IPED.fasta",
        names  = "results/{run}/per_sample/{sample}/10_iped/{sample}.IPED.names",
        groups = "results/{run}/per_sample/{sample}/10_iped/{sample}.IPED.groups"
    log:
        "results/{run}/logs/per_sample/{sample}/10_iped.log"
    conda:
        "../../envs/perl.yaml"
    params:
        outdir     = "results/{run}/per_sample/{sample}/10_iped",
        processors = config["processors"],
        iped       = IPED_SCRIPT
    shell:
        """
        # Run IPED denoising
        perl {params.iped} \
            _n {input.names} \
            _f {input.fasta} \
            _c {input.contig} \
            _q {input.qual} \
            _p {params.processors} \
            _o {params.outdir} \
            _i {wildcards.sample} \
            >> {log} 2>&1

        # Create groups file: prepend sample label to each accession
        perl -pe 's/^([\w\W]+)\n/$1\t{wildcards.sample}\n/g' \
            {input.accnos} > {output.groups} 2>> {log}

        # Move IPED outputs to standard names
        mv {params.outdir}/IPED_Final/{wildcards.sample}/Results.IPED.fasta {output.fasta}
        mv {params.outdir}/IPED_Final/{wildcards.sample}/Results.IPED.names {output.names}
        """
