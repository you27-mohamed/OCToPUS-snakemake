rule mothur_screen_seqs:
    input:
        align = f"{OUT}/per_sample/{{sample}}/05_mothur_align/{{sample}}.align",
        names = f"{OUT}/per_sample/{{sample}}/04_mothur_derep1/{{sample}}.names"
    output:
        align = temp(f"{OUT}/per_sample/{{sample}}/06_mothur_screen/{{sample}}.good.align"),
        names = temp(f"{OUT}/per_sample/{{sample}}/06_mothur_screen/{{sample}}.good.names")
    log:
        f"{OUT}/logs/per_sample/{{sample}}/06_mothur_screen.log"
    params:
        outdir   = f"{OUT}/per_sample/{{sample}}/06_mothur_screen",
        criteria = config["mothur"]["align_criteria"],
        mothur   = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});screen.seqs(fasta={input.align},name={input.names},optimize=start-end-length,criteria={params.criteria})" \
            >> {log} 2>&1
        # screen.seqs inserts .good. before extension: {{sample}}.good.align, {{sample}}.good.names — matches output directly
        """
