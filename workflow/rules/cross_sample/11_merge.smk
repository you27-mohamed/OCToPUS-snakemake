rule merge_samples:
    input:
        fasta  = expand("results/{run}/per_sample/{sample}/10_iped/{sample}.IPED.fasta",
                        run=RUN, sample=SAMPLES),
        names  = expand("results/{run}/per_sample/{sample}/10_iped/{sample}.IPED.names",
                        run=RUN, sample=SAMPLES),
        groups = expand("results/{run}/per_sample/{sample}/10_iped/{sample}.IPED.groups",
                        run=RUN, sample=SAMPLES)
    output:
        fasta  = temp(f"results/{RUN}/cross_sample/11_merge/All.fasta"),
        names  = temp(f"results/{RUN}/cross_sample/11_merge/All.names"),
        group  = temp(f"results/{RUN}/cross_sample/11_merge/All.group")
    log:
        f"results/{RUN}/logs/cross_sample/11_merge.log"
    shell:
        """
        cat {input.fasta} > {output.fasta} 2>> {log}
        cat {input.names} > {output.names} 2>> {log}
        cat {input.groups} > {output.group} 2>> {log}
        """
