MOTHUR2UPARSE = "workflow/scripts/external/catch/mothur2uparse.pl"

rule uparse_format:
    input:
        fasta = f"results/{RUN}/cross_sample/18_mothur_split/All.pick.{{sample}}.fasta",
        names = f"results/{RUN}/cross_sample/18_mothur_split/All.pick.{{sample}}.names"
    output:
        uparse = temp(f"results/{RUN}/cross_sample/19_uparse_format/{{sample}}.uparse.fasta")
    log:
        f"results/{RUN}/logs/cross_sample/19_uparse_format/{{sample}}.log"
    conda:
        "../../envs/perl.yaml"
    params:
        outdir = f"results/{RUN}/cross_sample/19_uparse_format",
        mothur = MOTHUR_BIN,
        m2u    = MOTHUR2UPARSE
    shell:
        """
        mkdir -p {params.outdir}
        {params.mothur} "#set.dir(output={params.outdir});set.logfile(name={log},append=T);sort.seqs(fasta={input.fasta},name={input.names})" \
            >> {log} 2>&1

        sorted_fasta={params.outdir}/$(basename {input.fasta} .fasta).sorted.fasta
        sorted_names={params.outdir}/$(basename {input.names} .names).sorted.names

        perl {params.m2u} "$sorted_fasta" "$sorted_names" a {wildcards.sample} \
            > {output.uparse} 2>> {log}
        """
