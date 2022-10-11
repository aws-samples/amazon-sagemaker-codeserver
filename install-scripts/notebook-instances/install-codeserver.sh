# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############

CODE_SERVER_VERSION="4.5.2"
CODE_SERVER_INSTALL_LOC="/home/ec2-user/SageMaker/.cs"
XDG_DATA_HOME="/home/ec2-user/SageMaker/.xdg/data"
XDG_CONFIG_HOME="/home/ec2-user/SageMaker/.xdg/config"
INSTALL_PYTHON_EXTENSION=1
CREATE_NEW_CONDA_ENV=1
CONDA_ENV_LOCATION='/home/ec2-user/SageMaker/.cs/conda/envs/codeserver_py39'
CONDA_ENV_PYTHON_VERSION="3.9"
INSTALL_DOCKER_EXTENSION=1
USE_CUSTOM_EXTENSION_GALLERY=0

sudo -u ec2-user -i <<EOF

unset SUDO_UID

#############
#  INSTALL  #
#############

# set the data and config home env variable for code-server
export XDG_DATA_HOME=$XDG_DATA_HOME
export XDG_CONFIG_HOME=$XDG_CONFIG_HOME
export PATH="$CODE_SERVER_INSTALL_LOC/bin/:$PATH"

# install code-server standalone
mkdir -p ${CODE_SERVER_INSTALL_LOC}/lib ${CODE_SERVER_INSTALL_LOC}/bin
curl -fL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz \
| tar -C ${CODE_SERVER_INSTALL_LOC}/lib -xz
mv ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION-linux-amd64 ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION
ln -s ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION/bin/code-server ${CODE_SERVER_INSTALL_LOC}/bin/code-server

# create separate conda environment
if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
then
    conda create --prefix $CONDA_ENV_LOCATION python=$CONDA_ENV_PYTHON_VERSION -y
fi

# install ms-python extension
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 0 -a $INSTALL_PYTHON_EXTENSION -eq 1 ]
then
    code-server --install-extension ms-python.python --force

    # if the new conda env was created, add configuration to set as default
    if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
    then
        CODE_SERVER_MACHINE_SETTINGS_FILE="$XDG_DATA_HOME/code-server/Machine/settings.json"
        if grep -q "python.defaultInterpreterPath" "\$CODE_SERVER_MACHINE_SETTINGS_FILE"
        then
            echo "Default interepreter path is already set."
        else
            cat >>\$CODE_SERVER_MACHINE_SETTINGS_FILE <<- MACHINESETTINGS
{
    "python.defaultInterpreterPath": "$CONDA_ENV_LOCATION/bin"
}
MACHINESETTINGS
        fi
    fi
fi

# install docker extension
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 0 -a $INSTALL_DOCKER_EXTENSION -eq 1 ]
then
    code-server --install-extension ms-azuretools.vscode-docker --force
fi

EOF
