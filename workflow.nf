 #! /usr/bin/env nextflow


process ENVSETUP {
    output: 
    path "" // this is just to make the recurrent processes wait

    script:
    """
    if [ ! -d $params.amplify_env_directory ]; then
        echo "sa"
        conda env create --name amplify_env --file $projectDir/amplify_environment.yml
    fi
    if [ ! -d $params.tamper_env_directory ]; then
        echo "as"
        conda env create --name tamper_env --file $projectDir/tamper_environment.yml
    fi
    """
}

/*
 * definition of the process "data preperation" which downloads the data to be used 
 * from the input of the workflow based on the user's run command to start the pipeline
 */
process DATAPREP {
    input:
    path x // this will not be used since the only reason for this is to make the process wait

    output: 
    path "" // again, just to make the processes wait
    
    script:
    if (params.input_path != "$projectDir/data/AMPlify_AMP_test_common.fa")
        """
        wget -O downloaded_input.fa -P $projectDir/data $params.input_path
        """
    else
        """
        """
}

process RUNAMPLIFY {
    input:
    path data_path

    script:
    """
    mkdir ${projectDir}/run_output
    echo "hi"
    """
}

process RUNTAMPER {

    script:
    """
    mkdir $projectDir/run_output
    """
}


workflow{
    wait_ch = ENVSETUP()
    input_data_ch = DATAPREP(wait_ch)
    output_amplify = RUNAMPLIFY(input_data_ch)
    // output_tamper = RUNTAMPER(input_data_ch)
}