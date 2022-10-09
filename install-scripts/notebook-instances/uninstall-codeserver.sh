# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############
CODE_SERVER_INSTALL_LOC="/home/ec2-user/SageMaker/.cs"
XDG_DATA_HOME="/home/ec2-user/SageMaker/.xdg/data"
XDG_CONFIG_HOME="/home/ec2-user/SageMaker/.xdg/config"
CREATE_NEW_CONDA_ENV=1
CONDA_ENV_LOCATION='/home/ec2-user/SageMaker/.cs/conda/envs/codeserver_py39'

PROXY_PATH='codeserver'
LAB_3_EXTENSION_NAME='sagemaker-jproxy-launcher-ext'
INSTALL_LAB1_EXTENSION=1
LAB_1_EXTENSION_NAME='@amzn/sagemaker-jproxy-launcher-ext-jl1'

###############
#  UNINSTALL  #
###############

JUPYTER_LAB_VERSION=$(/home/ec2-user/anaconda3/envs/JupyterSystemEnv/bin/jupyter-lab --version)

echo "Killing running code-server processes..."
ps uxa | grep code-server | awk '{print $2}' | xargs -i sh -c "kill {} -9 || true"

echo "Removing Jupyter notebook config for the proxied service..."
echo "!![[ Remember to update the jupyter-server-proxy configuration in /home/ec2-user/.jupyter/jupyter_notebook_config.py ]]!!"
#rm -f /home/ec2-user/.jupyter/jupyter_notebook_config.py 

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

sudo -u ec2-user -i <<EOF

if [[ $JUPYTER_LAB_VERSION == 1* ]]
then
    if [ $INSTALL_LAB1_EXTENSION -eq 1 ]
    then
        echo "Uninstalling JL1 extension..."

        source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv
        jupyter labextension uninstall $LAB_1_EXTENSION_NAME
        conda deactivate
    fi
else
    echo "Uninstalling JL3 extension..."
    
    source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv
    pip uninstall -y $LAB_3_EXTENSION_NAME
    jupyter labextension enable jupyterlab-server-proxy
    conda deactivate
fi

sudo systemctl restart jupyter-server

EOF
