# Jupyter Server Proxy lab extension (JupyterLab 3)
JupyterLab 3 extension that provides buttons in the SageMaker Studio and SageMaker Notebook Instance launchers to open code-server.
The extension parses the configuration of the proxied services enabled with [Jupyter Server Proxy](https://github.com/jupyterhub/jupyter-server-proxy) server extension and generates the corresponding launcher items.

## Build

    npm install
    npm run build:prod

## Package

    python3 setup.py sdist --formats=gztar

## Install (Studio and Notebook Instances)

    pip install sagemaker-jproxy-launcher-ext-X.Y.Z.tar.gz
