CATCH_SCRIPT = "workflow/scripts/external/catch/CATCh.pl"

rule catch_ensemble:
    input:
        fasta   = f"results/{RUN}/cross_sample/11_merge/All.fasta",
        names   = f"results/{RUN}/cross_sample/11_merge/All.names",
        uchime  = f"results/{RUN}/cross_sample/13_chimera_uchime/All.unique.uchime.chimeras",
        slayer  = f"results/{RUN}/cross_sample/14_chimera_slayer/All.unique.slayer.chimeras",
        perseus = f"results/{RUN}/cross_sample/15_chimera_perseus/All.unique.perseus.chimeras"
    output:
        result = f"results/{RUN}/cross_sample/16_catch/CATCH_Result.arff.Final_Result"
    log:
        f"results/{RUN}/logs/cross_sample/16_catch.log"
    conda:
        "../../envs/perl.yaml"
    params:
        outdir     = f"results/{RUN}/cross_sample/16_catch",
        processors = config["processors"],
        catch      = CATCH_SCRIPT
    shell:
        """
        perl {params.catch} \
            _f {input.fasta} \
            _n {input.names} \
            _h {params.outdir} \
            _i All \
            _m d \
            _p {params.processors} \
            _y {input.slayer} \
            _z {input.perseus} \
            _x {input.uchime} \
            >> {log} 2>&1
        """
