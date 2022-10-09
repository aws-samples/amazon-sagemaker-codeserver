# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############
CODE_SERVER_INSTALL_LOC="/opt/.cs"
XDG_DATA_HOME="/opt/.xdg/data"
XDG_CONFIG_HOME="/opt/.xdg/config"
CREATE_NEW_CONDA_ENV=1
CONDA_ENV_LOCATION='/opt/.cs/conda/envs/codeserver_py39'

PROXY_PATH='codeserver'
LAB_3_EXTENSION_NAME='sagemaker-jproxy-launcher-ext'
INSTALL_LAB1_EXTENSION=1
LAB_1_EXTENSION_NAME='@amzn/sagemaker-jproxy-launcher-ext-jl1'

###############
#  UNINSTALL  #
###############

echo "Killing running code-server processes..."
ps uxa | grep code-server | awk '{print $2}' | xargs -i sh -c "kill {} -9 || true"

echo "Removing Jupyter notebook config for the proxied service..."
rm -f /home/sagemaker-user/.jupyter/jupyter_notebook_config.py 

export AWS_SAGEMAKER_JUPYTERSERVER_IMAGE="${AWS_SAGEMAKER_JUPYTERSERVER_IMAGE:-'jupyter-server-3'}"

if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
then
    echo "Deleting Conda environment..."
    sudo rm -rf $CONDA_ENV_LOCATION
fi

echo "Deleting code-server config..."
sudo rm -rf $XDG_CONFIG_HOME/code-server

echo "Deleting code-server data..."
sudo rm -rf $XDG_DATA_HOME/code-server

echo "Deleting code-server..."
sudo rm -rf $CODE_SERVER_INSTALL_LOC

if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server-3" ]
then
    echo "Uninstalling JL3 extension..."

    eval "$(conda shell.bash hook)"
    conda activate studio
    pip uninstall -y $LAB_3_EXTENSION_NAME
    conda deactivate

    restart-jupyter-server 
    sleep 10
fi

if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server" ]
then
    if [ $INSTALL_LAB1_EXTENSION -eq 1 ]
    then
        echo "Uninstalling JL1 extension..."
        jupyter labextension uninstall $LAB_1_EXTENSION_NAME --no-build
        jupyter lab build --debug --minimize=False
    fi

    nohup supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart jupyterlabserver
fi
