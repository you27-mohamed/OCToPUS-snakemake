rule chimera_perseus_per_sample:
    input:
        fasta = f"{OUT}/cross_sample/12_mothur_unique_all/All.unique.fasta",
        names = f"{OUT}/cross_sample/12_mothur_unique_all/All.unique.names",
        group = f"{OUT}/cross_sample/11_merge/All.group"
    output:
        chimeras = temp(f"{OUT}/cross_sample/15_chimera_perseus/per_sample/{{sample}}.chimeras")
    log:
        f"{OUT}/logs/cross_sample/15_chimera_perseus_{{sample}}.log"
    threads: 1
    params:
        sampledir = lambda wc: f"{OUT}/cross_sample/15_chimera_perseus/per_sample/{wc.sample}",
        mothur    = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.sampledir}
        {params.mothur} "#set.dir(output={params.sampledir});get.groups(fasta={input.fasta},name={input.names},group={input.group},groups={wildcards.sample})" \
            >> {log} 2>&1
        {params.mothur} "#set.dir(output={params.sampledir});chimera.perseus(fasta={params.sampledir}/All.unique.pick.fasta,name={params.sampledir}/All.unique.pick.names)" \
            >> {log} 2>&1
        mv {params.sampledir}/All.unique.pick.perseus.chimeras {output.chimeras}
        """


rule chimera_perseus:
    input:
        per_sample = expand(
            f"{OUT}/cross_sample/15_chimera_perseus/per_sample/{{sample}}.chimeras",
            sample=SAMPLES
        )
    output:
        chimeras = f"{OUT}/cross_sample/15_chimera_perseus/All.unique.perseus.chimeras"
    log:
        f"{OUT}/logs/cross_sample/15_chimera_perseus_merge.log"
    params:
        first = lambda wc, input: input.per_sample[0]
    shell:
        """
        head -1 {params.first} > {output.chimeras}
        for f in {input.per_sample}; do
            tail -n +2 "$f" >> {output.chimeras}
        done
        """
