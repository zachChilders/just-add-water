# Just Add Water

![Just Add Water](images/martians.png)

## Instant Cloud Scale, No Matter What You Deploy

Just Add Water (jaw) is a template repo designed to Securely and Reliably deploy any and all of your services with no additional effort from you.  By offloading provisioning and initial deployments here, it is possible to build an environment where a [Homogenous Infrastructure](link) requires no additional work.  This approach promotes management, maintainability, and security to be first class citizens in a codebase without distracting from important application features.

## Reliable Automation

jaw applies DevOps best practices that ensure you go to production with confidence.  It leverages [microsoft/Requirements](https://github.com/microsoft/Requirements) in order to declaratively create and configure secure cloud infrastructure with no necessary user action.

We currently are focused on Azure based infrastructure, but want to support as many environments as possible.

## Secure By Design

jaw applies defense in depth to existing codebases to establish a secure baseline and improve your security posture with every deployment.

## Usage

1. Generate a new repo using [this repo as a template](https://github.com/zachChilders/just-add-water/generate)
2. `git submodule update` whatever docker application you need.
3. Run deploy.ps1

## Dependencies

We ship jaw in a VSCode dev container.  This means you only need to install the following:

- Docker

- VSCode

- [Remote Containers Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

You can then just do `code .` in the top level of this repo and follow VSCode's prompts to get a clean environment.  The first time you do this will take a couple
minutes while it builds your environment.

If you would prefer a purely native environment, you can install the following dependencies:

- [az cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

- [Terraform](https://www.terraform.io/downloads.html)

- kubectl - `az aks install-cli`

You also will need to have access to an Azure subscription with the following dedicated resources available to your user account:
- Container Registry
- Key Vault
