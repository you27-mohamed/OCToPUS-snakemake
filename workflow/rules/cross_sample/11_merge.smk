rule merge_samples:
    input:
        fasta  = expand(f"{OUT}/per_sample/{{sample}}/10_iped/{{sample}}.IPED.fasta",
                        sample=SAMPLES),
        names  = expand(f"{OUT}/per_sample/{{sample}}/10_iped/{{sample}}.IPED.names",
                        sample=SAMPLES),
        groups = expand(f"{OUT}/per_sample/{{sample}}/10_iped/{{sample}}.IPED.groups",
                        sample=SAMPLES)
    output:
        fasta  = temp(f"{OUT}/cross_sample/11_merge/All.fasta"),
        names  = temp(f"{OUT}/cross_sample/11_merge/All.names"),
        group  = temp(f"{OUT}/cross_sample/11_merge/All.group")
    log:
        f"{OUT}/logs/cross_sample/11_merge.log"
    shell:
        """
        cat {input.fasta} > {output.fasta} 2>> {log}
        cat {input.names} > {output.names} 2>> {log}
        cat {input.groups} > {output.group} 2>> {log}
        """
