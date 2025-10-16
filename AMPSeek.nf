 #! /usr/bin/env nextflow
nextflow.enable.dsl = 2

process DOWNLOADSEQUENCES {
    tag "Preparing for execution /  Downloading requested data"
    publishDir "$params.output_path"
    cpus params.threads
    time "${params.time ?: ''}"

    output:
    path ""    

    script:
    if (params.download_from)
        """
        if [ -d "$params.data_path" ]; then
            checksum=\$(find "$params.data_path" -type f -exec md5sum {} + | md5sum | cut -d ' ' -f1)
            backup_dir="${params.data_path}_backup_\${checksum}"
            if [ -d "\$backup_dir" ]; then
                echo "Backup already exists (\$backup_dir), skipping new backup."
            else
                echo "Backing up existing data to: \$backup_dir"
                mv "$params.data_path" "\$backup_dir"
            fi
        fi

        # Recreate data directory and download new data
        mkdir -p "$params.data_path"
        wget -O "$params.data_path/downloaded_input.fa" "$params.download_from"
        """
    else
        """
        mkdir -p "$params.output_path"
        """
}

process RUNAMPLIFY {
    tag "Running AMPlify"
    cpus params.threads
    time "${params.time ?: ''}"

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
    cpus params.threads
    time "${params.time ?: ''}"

    input:
    path data_path
    path output_path
    path wait

    output:
    path "$output_path/foldings"

    script:
    """
    colabfold_batch --amber --zip $data_path $output_path/foldings
    """
}

process RUNTAMPER {
    tag "Running tAMPer"
    cpus params.threads
    time "${params.time ?: ''}"

    input:
    path input_data
    path structure_data
    path output_path

    output:
    path "$output_path/results.csv"

    script:
    """
    python /opt/tAMPer/src/predict_tAMPer.py -seqs $input_data -pdbs $structure_data -chkpnt /opt/tAMPer/checkpoints/trained/chkpnt.pt -out $output_path
    find $structure_data -type f ! -name '*.zip' -delete
    """
}

process COMPILERESULTS{
    tag "Compiling results"
    cpus params.threads
    time "${params.time ?: ''}"

    input:
    path amplify
    path tamper
    path colabfold
    path compiler_path
    path imgs
    path templates

    script:
    if(params.output_file)
        """
        python $compiler_path $amplify $tamper $colabfold $params.output_path/$params.output_file $imgs $templates
        rm -f $params.output_path/AMPlify*.tsv
        rm -f $params.output_path/*.csv
        """
    else
        """
        python $compiler_path $amplify $tamper $colabfold $params.output_path/results.html $imgs $templates
        rm -f $params.output_path/AMPlify*.tsv
        rm -f $params.output_path/*.csv
        """
}

workflow{
    prep_out = DOWNLOADSEQUENCES()

    input_data_ch = prep_out.data_files
    output_data_ch = Channel.fromPath("$params.output_path")
    compiler_path = Channel.fromPath("$projectDir/src/make_report.py")
    template_path = Channel.fromPath("$projectDir/templates/report_template.html")
    img_path = Channel.fromPath("$projectDir/imgs/Logo.png")
    
    output_amplify = RUNAMPLIFY(input_data_ch, output_data_ch, prep_out)
    output_colabfold = RUNCOLABFOLD(input_data_ch, output_data_ch, prep_out)
    output_tamper = RUNTAMPER(input_data_ch, output_colabfold, output_data_ch)
    COMPILERESULTS(output_amplify, output_tamper, output_colabfold, compiler_path, img_path, template_path)
}

workflow.onComplete {
    log.info ( workflow.success ? "\nDone! The output is in --> $params.output_path\n" : "Oops .. something went wrong" )
}
