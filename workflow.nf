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
    tag "Running AMPlify"

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
    tag "Running colabfold"

    input:
    path data_path
    path output_path
    path wait

    output:
    path "$output_path/foldings"

    script:
    """
    colabfold_batch --amber --templates --zip --num-recycle 3 $data_path $output_path/foldings
    """
}

process RUNTAMPER {
    tag "Running tAMPer"

    input:
    path input_data
    path structure_data
    path output_path

    output:
    path "$output_path/results.csv"

    script:
    """
    python ${projectDir}/subprojects/tAMPer/src/predict_tAMPer.py -seqs $input_data -pdbs $structure_data -hdim 64 -embedding_model t12 -d_max 12 -chkpnt ${projectDir}/subprojects/tAMPer/checkpoints/trained/chkpnt.pt -out $output_path
    """
}

process COMPILERESULTS{
    input:
    path amplify
    path tamper
    path compiler_path

    script:
    if(params.output_file!='')
        """
        python $compiler_path $amplify $tamper $params.output_path/$params.output_file 
        rm -f $params.output_path/AMPlify*.tsv
        rm -f $params.output_path/*.csv
        """
    else
        """
        python $compiler_path $amplify $tamper $params.output_path/compiled_results.csv
        rm -f $params.output_path/AMPlify*.tsv
        rm -f $params.output_path/results.csv
        """
}

workflow{
    wait=PREP()
    input_data_ch = Channel.fromPath("$params.data_path/*.{fa, fna, fasta}")
    output_data_ch = Channel.fromPath("$params.output_path")
    compiler_path = Channel.fromPath("$projectDir/compile_results.py")
    
    output_amplify = RUNAMPLIFY(input_data_ch, output_data_ch, wait)
    output_colabfold = RUNCOLABFOLD(input_data_ch, output_data_ch, wait)
    output_tamper = RUNTAMPER(input_data_ch, output_colabfold, output_data_ch)
    COMPILERESULTS(output_amplify, output_tamper, compiler_path)
}

workflow.onComplete {
    log.info ( workflow.success ? "\nDone! The output is in --> $params.output_path\n" : "Oops .. something went wrong" )
}