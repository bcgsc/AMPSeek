 #! /usr/bin/env nextflow

/*
 * definition of the process "data preperation" which downloads the data to be used 
 * from the input of the workflow based on the user's run command to start the pipeline
 */
process PREP {
    publishDir "output"

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
        """
}

process RUNAMPLIFY {
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
    input:
    path data_path
    path output_path
    path wait

    output:
    path "$output_path"

    script:
    """
    colabfold_batch $data_path $output_path/foldings --num-recycle 1
    """
}

process ZIPFOLDS{
    input:
    path zipper
    path output_path

    output:
    path "$output_path/foldings"

    script:
    """
    file_path=\$(find  $output_path/foldings -maxdepth 1 -type f -name "*.a3m")
    echo \$file_path
    file_name=\$(basename \$file_path .a3m)
    echo \$file_name
    echo $output_path
    python zipper.py \$file_name $output_path/foldings
    """
}

process RUNTAMPER {
    input:
    path input_data
    path structure_data

    output:
    path "$structure_data/tamper_result.csv"

    script:
    """
    git clone https://github.com/bcgsc/tAMPer.git
    cd tAMPer
    git checkout 384889c5709044ff2c29cc253b613b9042f88f0b
    cd ..
    python tAMPer/src/predict.py -seqs $input_data -pdbs $structure_data -hdim 64 -embedding_model t12 -d_max 12 -chkpnt tAMPer/checkpoints/trained/chkpnt.pt -result_csv $structure_data/tamper_result.csv
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
    Rscript $rscript_path $amplify $colabfold/foldings $output_path/report.html
    """
}

workflow{
    wait=PREP()
    input_data_ch = Channel.fromPath("$params.data_path/*.fa")
    output_data_ch = Channel.fromPath("$params.output_path")
    zipper_ch = Channel.fromPath("$projectDir/zipper.py")
    rscript_path = Channel.fromPath("$projectDir/report.R")
    output_amplify = RUNAMPLIFY(input_data_ch, output_data_ch, wait)
    output_colabfold = RUNCOLABFOLD(input_data_ch, output_data_ch, wait)
    zip_ch = ZIPFOLDS(zipper_ch, output_colabfold)
    output_tamper = RUNTAMPER(input_data_ch, zip_ch)
    final_path = Channel.fromPath("$projectDir")
    COMPILERESULTS(output_amplify, output_colabfold, output_tamper, rscript_path, final_path)
}