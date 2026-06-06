rule mothur_screen_seqs:
    input:
        align = "results/{run}/per_sample/{sample}/05_mothur_align/{sample}.align",
        names = "results/{run}/per_sample/{sample}/04_mothur_derep1/{sample}.names"
    output:
        align = temp("results/{run}/per_sample/{sample}/06_mothur_screen/{sample}.good.align"),
        names = temp("results/{run}/per_sample/{sample}/06_mothur_screen/{sample}.good.names")
    log:
        "results/{run}/logs/per_sample/{sample}/06_mothur_screen.log"
    params:
        outdir   = "results/{run}/per_sample/{sample}/06_mothur_screen",
        criteria = config["mothur"]["align_criteria"],
        mothur   = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});screen.seqs(fasta={input.align},name={input.names},optimize=start-end-length,criteria={params.criteria})" \
            >> {log} 2>&1
        # screen.seqs inserts .good. before extension: {sample}.good.align, {sample}.good.names — matches output directly
        """
