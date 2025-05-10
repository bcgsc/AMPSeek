 #! /usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * definition of the process "data preperation" which downloads the data to be used 
 * from the input of the workflow based on the user's run command to start the pipeline
 */
process PREP {
    publishDir "$params.output_path"

    output:
    path ""    

    script:
    if (params.download == true)
        """
        rm $params.data_path/*.fa
        wget -O downloaded_input.fa -P $params.data_path $params.download_from
        """
    else
        """
        mkdir -p $params.output_path
        echo $params.data_path
        """
}

process RUNAMPLIFY {
    errorStrategy 'retry', maxRetries: 1
    tag "Running AMPlify"
    publishDir "$params.output_path"

    input:
    path data_path
    path output_path
    path wait

    output:
    path "$output_path/*.tsv"

    script:
    """
    AMPlify -m balanced -s $data_path -od $output_path -sub on -att on
    """
}

process RUNCOLABFOLD{
    errorStrategy 'retry', maxRetries: 1
    tag "Running colabfold"
    publishDir "$params.output_path"

    input:
    path data_path
    path output_path
    path wait

    output:
    path "$output_path"

    script:
    """
    colabfold_batch --amber --templates --zip --num-recycle 3 $data_path $output_path/foldings
    """
}

process RUNTAMPER {
    errorStrategy 'retry', maxRetries: 1
    tag "Running tAMPer"
    publishDir "$params.output_path"

    input:
    path input_data
    path structure_data

    output:
    path "$structure_data/tamper_result.csv"

    script:
    """
    python subprojects/tAMPer/src/predict.py -seqs $input_data -pdbs $structure_data -hdim 64 -embedding_model t12 -d_max 12 -chkpnt subprojects/tAMPer/checkpoints/trained/chkpnt.pt -result_csv $structure_data/tamper_result.csv
    """
}

process COMPILERESULTS{
    input:
    path amplify
    path colabfold
    path tamper
    path rscript_path
    path output_path

    script:
    """
    Rscript $rscript_path $amplify $colabfold/foldings $output_path/report.html $tamper
    """
}

workflow{
    wait=PREP()
    input_data_ch = Channel.fromPath("$params.data_path/*.{fa, fna, fasta}")
    output_data_ch = Channel.fromPath("$params.output_path")
    rscript_path = Channel.fromPath("$projectDir/report.R")
    final_path = Channel.fromPath("$projectDir")
    
    output_amplify = RUNAMPLIFY(input_data_ch, output_data_ch, wait)
    output_colabfold = RUNCOLABFOLD(input_data_ch, output_data_ch, wait)
    output_tamper = RUNTAMPER(input_data_ch, output_colabfold)
    COMPILERESULTS(output_amplify, output_colabfold, output_tamper, rscript_path, final_path)
}

workflow.onComplete {
    log.info ( workflow.success ? "\nDone! The ouput is in --> $output_path/report.html\n" : "Oops .. something went wrong" )
}