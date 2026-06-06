rule mothur_remove_chimeras:
    input:
        fasta  = f"results/{RUN}/cross_sample/11_merge/All.fasta",
        names  = f"results/{RUN}/cross_sample/11_merge/All.names",
        group  = f"results/{RUN}/cross_sample/11_merge/All.group",
        catch  = f"results/{RUN}/cross_sample/16_catch/CATCH_Result.arff.Final_Result"
    output:
        fasta  = temp(f"results/{RUN}/cross_sample/17_mothur_remove/All.pick.fasta"),
        names  = temp(f"results/{RUN}/cross_sample/17_mothur_remove/All.pick.names"),
        group  = temp(f"results/{RUN}/cross_sample/17_mothur_remove/All.pick.group"),
        accnos = temp(f"results/{RUN}/cross_sample/17_mothur_remove/chimeric.accnos")
    log:
        f"results/{RUN}/logs/cross_sample/17_mothur_remove.log"
    conda:
        "../../envs/mothur.yaml"
    params:
        outdir = f"results/{RUN}/cross_sample/17_mothur_remove"
    shell:
        """
        # Extract chimeric sequence IDs from CATCh result
        echo "CATCh_Chimera_Check" > {output.accnos}
        grep -P "\tChimeric" {input.catch} | cut -f1 >> {output.accnos} 2>> {log}

        mothur "#set.dir(output={params.outdir});
                set.logfile(name={log},append=T);
                remove.seqs(fasta={input.fasta},name={input.names},group={input.group},accnos={output.accnos})" \
            >> {log} 2>&1
        """
