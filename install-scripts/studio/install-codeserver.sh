# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############

CODE_SERVER_VERSION="4.5.2"
CODE_SERVER_INSTALL_LOC="/opt/.cs"
XDG_DATA_HOME="/opt/.xdg/data"
XDG_CONFIG_HOME="/opt/.xdg/config"
INSTALL_PYTHON_EXTENSION=1
CREATE_NEW_CONDA_ENV=1
CONDA_ENV_LOCATION='/opt/.cs/conda/envs/codeserver_py39'
CONDA_ENV_PYTHON_VERSION="3.9"
USE_CUSTOM_EXTENSION_GALLERY=0
EXTENSION_GALLERY_CONFIG='{{\"serviceUrl\":\"\",\"cacheUrl\":\"\",\"itemUrl\":\"\",\"controlUrl\":\"\",\"recommendationsUrl\":\"\"}}'

LAUNCHER_ENTRY_TITLE='Code Server'
PROXY_PATH='codeserver'
LAB_3_EXTENSION_DOWNLOAD_URL='https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v0.1.5/sagemaker-jproxy-launcher-ext-0.1.3.tar.gz'
INSTALL_LAB1_EXTENSION=1
LAB_1_EXTENSION_DOWNLOAD_URL='https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v0.1.5/amzn-sagemaker-jproxy-launcher-ext-jl1-0.1.4.tgz'

#############
#  INSTALL  #
#############

sudo mkdir -p /opt/.cs
sudo mkdir -p /opt/.xdg
sudo chown sagemaker-user /opt/.cs
sudo chown sagemaker-user /opt/.xdg

# set the data and config home env variable for code-server
export XDG_DATA_HOME=$XDG_DATA_HOME
export XDG_CONFIG_HOME=$XDG_CONFIG_HOME
export PATH="$CODE_SERVER_INSTALL_LOC/bin/:$PATH"

# install code-server standalone
mkdir -p ${CODE_SERVER_INSTALL_LOC}/lib ${CODE_SERVER_INSTALL_LOC}/bin
curl -fL https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz \
| tar -C ${CODE_SERVER_INSTALL_LOC}/lib -xz
rm -rf ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION
mv ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION-linux-amd64 ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION
ln -sf ${CODE_SERVER_INSTALL_LOC}/lib/code-server-$CODE_SERVER_VERSION/bin/code-server ${CODE_SERVER_INSTALL_LOC}/bin/code-server

# create new conda env
if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
then
    conda create --prefix $CONDA_ENV_LOCATION python=$CONDA_ENV_PYTHON_VERSION -y
    conda config --add envs_dirs "${CONDA_ENV_LOCATION%/*}"
fi

# install ms-python extension
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 0 -a $INSTALL_PYTHON_EXTENSION -eq 1 ]
then
    code-server --install-extension ms-python.python --force

    # if the new conda env was created, add configuration to set as default
    if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
    then
        CODE_SERVER_MACHINE_SETTINGS_FILE="$XDG_DATA_HOME/code-server/Machine/settings.json"
        if grep -q "python.defaultInterpreterPath" "$CODE_SERVER_MACHINE_SETTINGS_FILE"
        then
            echo "Default interepreter path is already set."
        else
            cat >>$CODE_SERVER_MACHINE_SETTINGS_FILE <<- MACHINESETTINGS
{
    "python.defaultInterpreterPath": "$CONDA_ENV_LOCATION/bin"
}
MACHINESETTINGS
        fi
    fi
fi

# use custom extension gallery
EXT_GALLERY_JSON=''
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 1 ]
then
    EXT_GALLERY_JSON="'EXTENSIONS_GALLERY': '$EXTENSION_GALLERY_CONFIG'"
fi

JUPYTER_CONFIG_FILE="/home/sagemaker-user/.jupyter/jupyter_notebook_config.py"
if grep -q "$CODE_SERVER_INSTALL_LOC/bin" "$JUPYTER_CONFIG_FILE"
then
    echo "Server-proxy configuration already set in Jupyter notebook config."
else
    mkdir -p /home/sagemaker-user/.jupyter
    cat >>/home/sagemaker-user/.jupyter/jupyter_notebook_config.py <<- NBCONFIG
c.ServerProxy.servers = {
    '$PROXY_PATH': {
        'launcher_entry': {
                'enabled': True,
                'title': '$LAUNCHER_ENTRY_TITLE',
                'icon_path': 'codeserver.svg'
        },
        'command': ['$CODE_SERVER_INSTALL_LOC/bin/code-server', '--auth', 'none', '--disable-telemetry', '--bind-addr', '127.0.0.1:{port}'],
        'environment' : {
                            'XDG_DATA_HOME' : '$XDG_DATA_HOME', 
                            'XDG_CONFIG_HOME': '$XDG_CONFIG_HOME',
                            'SHELL': '/bin/bash',
                            $EXT_GALLERY_JSON
                        },
        'absolute_url': False,
        'timeout': 30
    }
}
NBCONFIG
fi

export AWS_SAGEMAKER_JUPYTERSERVER_IMAGE="${AWS_SAGEMAKER_JUPYTERSERVER_IMAGE:-'jupyter-server-3'}"

if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server-3" ]
then
    eval "$(conda shell.bash hook)"
    conda activate studio

    # Install JL3 extension
    mkdir -p $CODE_SERVER_INSTALL_LOC/lab_ext
    curl -L $LAB_3_EXTENSION_DOWNLOAD_URL > $CODE_SERVER_INSTALL_LOC/lab_ext/sagemaker-jproxy-launcher-ext.tar.gz
    pip install $CODE_SERVER_INSTALL_LOC/lab_ext/sagemaker-jproxy-launcher-ext.tar.gz

    jupyter labextension disable jupyterlab-server-proxy

    conda deactivate

    restart-jupyter-server

    sleep 10
fi

if [ "$AWS_SAGEMAKER_JUPYTERSERVER_IMAGE" = "jupyter-server" ]
then
    nohup supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart jupyterlabserver
    
    # Install JL1 extension
    if [ $INSTALL_LAB1_EXTENSION -eq 1 ]
    then
        rm -f $CODE_SERVER_INSTALL_LOC/install-jl1-extension.sh
        cat >>$CODE_SERVER_INSTALL_LOC/install-jl1-extension.sh <<- JL1EXT
sleep 15

mkdir -p $CODE_SERVER_INSTALL_LOC/lab_ext
curl -L $LAB_1_EXTENSION_DOWNLOAD_URL > $CODE_SERVER_INSTALL_LOC/lab_ext/amzn-sagemaker-jproxy-launcher-ext-jl1.tgz

cd $CODE_SERVER_INSTALL_LOC/lab_ext
jupyter labextension install amzn-sagemaker-jproxy-launcher-ext-jl1.tgz --no-build
jlpm config set cache-folder /tmp/yarncache
jupyter lab build --debug --minimize=False

supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart jupyterlabserver
JL1EXT
        sudo chmod +x $CODE_SERVER_INSTALL_LOC/install-jl1-extension.sh
        nohup $CODE_SERVER_INSTALL_LOC/install-jl1-extension.sh &
    fi
fi
