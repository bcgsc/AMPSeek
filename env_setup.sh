#!/bin/bash

amplify_env_directory=~/.conda/envs/amplify_env
tamper_env_directory=~/.conda/envs/tamper_env
if [ ! -d "$amplify_env_directory" ]; then
    conda env create --name amplify_env --file amplify_environment.yml
fi
if [ ! -d "$tamper_env_directory" ]; then
    conda env create --name tamper_env --file tamper_environment.yml
fi