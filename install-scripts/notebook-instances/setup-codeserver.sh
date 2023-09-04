# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#!/bin/bash
set -eux

###############
#  VARIABLES  #
###############

CODE_SERVER_VERSION="4.16.1"
CODE_SERVER_INSTALL_LOC="/home/ec2-user/SageMaker/.cs"
XDG_DATA_HOME="/home/ec2-user/SageMaker/.xdg/data"
XDG_CONFIG_HOME="/home/ec2-user/SageMaker/.xdg/config"
CREATE_NEW_CONDA_ENV=1
CONDA_ENV_LOCATION='/home/ec2-user/SageMaker/.cs/conda/envs/codeserver_py39'
USE_CUSTOM_EXTENSION_GALLERY=0
EXTENSION_GALLERY_CONFIG='{{\"serviceUrl\":\"\",\"cacheUrl\":\"\",\"itemUrl\":\"\",\"controlUrl\":\"\",\"recommendationsUrl\":\"\"}}'

LAUNCHER_ENTRY_TITLE='Code Server'
PROXY_PATH='codeserver'
LAB_3_EXTENSION_DOWNLOAD_URL='https://github.com/aws-samples/amazon-sagemaker-codeserver/releases/download/v0.2.0/sagemaker-jproxy-launcher-ext-0.2.0.tar.gz'

#############
#  INSTALL  #
#############

export XDG_DATA_HOME=$XDG_DATA_HOME
export XDG_CONFIG_HOME=$XDG_CONFIG_HOME
export PATH="${CODE_SERVER_INSTALL_LOC}/bin/:$PATH"

# use custom extension gallery
EXT_GALLERY_JSON=''
if [ $USE_CUSTOM_EXTENSION_GALLERY -eq 1 ]
then
    EXT_GALLERY_JSON="'EXTENSIONS_GALLERY': '$EXTENSION_GALLERY_CONFIG'"
fi

JUPYTER_CONFIG_FILE="/home/ec2-user/.jupyter/jupyter_notebook_config.py"
if grep -q "$CODE_SERVER_INSTALL_LOC/bin" "$JUPYTER_CONFIG_FILE"
then
    echo "Server-proxy configuration already set in Jupyter notebook config."
else
    cat >>/home/ec2-user/.jupyter/jupyter_notebook_config.py <<EOC
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
EOC
fi

JUPYTER_LAB_VERSION=$(/home/ec2-user/anaconda3/envs/JupyterSystemEnv/bin/jupyter-lab --version)

sudo -u ec2-user -i <<EOF

if [ $CREATE_NEW_CONDA_ENV -eq 1 ]
then
    conda config --add envs_dirs "${CONDA_ENV_LOCATION%/*}"
fi

if [[ $JUPYTER_LAB_VERSION == 1* ]]
then
    source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv
    echo "Installing jupyter-server-proxy."
    pip install jupyter-server-proxy==1.6.0
    conda deactivate

    echo "JupyterLab extension for JupyterLab 1 is not supported. You can still access code-server by typing the code-server URL in the browser address bar."
else
    source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv

    # Install JL3 extension
    mkdir -p $CODE_SERVER_INSTALL_LOC/lab_ext
    curl -L $LAB_3_EXTENSION_DOWNLOAD_URL > $CODE_SERVER_INSTALL_LOC/lab_ext/sagemaker-jproxy-launcher-ext.tar.gz
    pip install $CODE_SERVER_INSTALL_LOC/lab_ext/sagemaker-jproxy-launcher-ext.tar.gz

    jupyter labextension disable jupyterlab-server-proxy

    conda deactivate
fi
EOF

if [[ -f /home/ec2-user/bin/dockerd-rootless.sh ]]; then
	echo "Running in rootless mode; please restart Jupyter Server from the 'File' > 'Shut Down' menu and re-open Jupyter/JupyterLab."
else
	echo "Root mode. Restarting Jupyter Server..."
    sudo systemctl restart jupyter-server
fi
