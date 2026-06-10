rule mothur_remove_chimeras:
    input:
        fasta  = f"{OUT}/cross_sample/11_merge/All.fasta",
        names  = f"{OUT}/cross_sample/11_merge/All.names",
        group  = f"{OUT}/cross_sample/11_merge/All.group",
        catch  = f"{OUT}/cross_sample/16_catch/CATCH_Result.arff.Final_Result"
    output:
        fasta  = temp(f"{OUT}/cross_sample/17_mothur_remove/All.pick.fasta"),
        names  = temp(f"{OUT}/cross_sample/17_mothur_remove/All.pick.names"),
        group  = temp(f"{OUT}/cross_sample/17_mothur_remove/All.pick.group"),
        accnos = temp(f"{OUT}/cross_sample/17_mothur_remove/chimeric.accnos")
    log:
        f"{OUT}/logs/cross_sample/17_mothur_remove.log"
    params:
        outdir = f"{OUT}/cross_sample/17_mothur_remove",
        mothur = MOTHUR_BIN
    shell:
        """
        mkdir -p {params.outdir}
        echo "CATCh_Chimera_Check" > {output.accnos}
        grep -P "\tChimeric" {input.catch} | cut -f1 >> {output.accnos} 2>> {log}
        {params.mothur} "#set.dir(output={params.outdir});set.logfile(name={log},append=T);remove.seqs(fasta={input.fasta},name={input.names},group={input.group},accnos={output.accnos})" \
            >> {log} 2>&1
        """
