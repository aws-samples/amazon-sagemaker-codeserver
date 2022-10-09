# Jupyter Server Proxy lab extension (JupyterLab 1)
JupyterLab 1 extension that provides buttons in the SageMaker Studio and SageMaker Notebook Instance launchers to open code-server.
The extension parses the configuration of the proxied services enabled with [Jupyter Server Proxy](https://github.com/jupyterhub/jupyter-server-proxy) server extension and generates the corresponding launcher items.

## Build

    npm install
    npm run build

## Package

    mkdir -p dist
    npm pack --pack-destination dist

## Install (Studio and Notebook Instances)

    jupyter labextension install amzn-sagemaker-jproxy-launcher-ext-jl1-X.Y.Z.tgz --no-build
    jupyter lab build --debug --minimize=False
