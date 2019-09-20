Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# TODO: Set these better
$tf_share = "zachterraformstorage"
$kv_name = "mics-kv"
$acr_name = "mics233.azurecr.io"

Import-Module -Name "./modules/jaw"

"Requirements" | % {
    if (-not (Get-InstalledModule  $_)) {
        Install-Module $_ -Force
    }
    Import-Module $_
}

# Auth Azure and gather subscription secrets
$azureReqs = @(
    @{
        Name     = "Azure Login"
        Describe = "Authenticate Azure Session"
        Test     = {
            (az account show | ConvertFrom-Json).state -eq "Enabled"
        }
        Set      = { az login | Out-Null }
    },
    @{  # This could be done idempotently with a test,
        # but refreshing the secrets every run allows for
        # new secrets to be added easily
        Name     = "Keyvault Secrets"
        Describe = "Inject Secrets into Session"
        Set      = {
            $KEYVAULTNAME = $kv_name
            $SECRETS = ( $(az keyvault secret list --vault-name $KEYVAULTNAME | jq '.[].id' -r | sed 's/.*\/\([^/]\+\)$/\1/') )
            $SECRETS | % {
                $SECRET = $(az keyvault secret show --name $_ --vault-name $KEYVAULTNAME | jq '.value' -r)
                $NAME = $_.Replace("-", "_")
                [Environment]::SetEnvironmentVariable($NAME, $SECRET)
            }
        }
    }
)

# Provision Infra
$provisionReqs = @(
    @{
        Name     = "Terraform init"
        Describe = "Initialize terraform environment"
        Test     = { Test-Path "$PSScriptRoot/tf/.terraform" }
        Set      = {
            Set-Location -Path "tf"
            terraform init -backend-config="storage_account_name=$($tf_share)" -backend-config="container_name=tfstate" -backend-config="access_key=$($env:terraform_storage_key)" -backend-config="key=mics.tfstate" | Out-Null
        }
    },
    @{
        Name     = "Terraform plan"
        Describe = "Plan terraform environment"
        Test     = { Test-Path "$PSScriptRoot/out/out.plan" }
        Set      = {
            New-Item -Path "$PSScriptRoot/out" -ItemType Directory -Force
            terraform plan -out "$PSScriptRoot/out/out.plan" | Out-Null
        }
    },
    @{
        Name     = "Terraform Apply"
        Describe = "Apply Terraform plan"
        Set      = {
            terraform apply "$PSScriptRoot/out/out.plan" | Write-Information
            terraform output kube_config | Out-File "$PSScriptRoot/out/azurek8s"
            Set-Location -Path ".."
        }
    }
)

# Docker cooking
$dockerReqs = @(
    @{
        Name     = "Find Docker Services"
        Describe = "Enumerate Containers"
        Set      = {
            Set-k8sConfig
        }
    },
    @{
        Name     = "Build Docker Containers"
        Describe = "Build all containers"
        Set      = {
            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $list | % { docker build -t "$acr_name/$($_.Name)" $_.Path }
            $null
        }
    },
    @{
        Name     = "Push Containers"
        Describe = "Push all containers"
        Set      = {
            docker login $acr_name -u mics233 -p $env:acrpassword

            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $list | % { docker push "$acr_name/$($_.Name)" }
            $null
        }
    }
)

# Kubernetes Deployment
$k8sReqs = @(
    @{
        Name     = "Load Config"
        Describe = "Load k8s config"
        Set      = {
            $env:KUBECONFIG = "./out/azurek8s"
        }
    },
    @{
        Name     = "Deploy Application"
        Describe = "Application deployment"
        Set      = {
            kubectl apply -f pod.yml
            $null
        }
    },
    @{
        Name     = "Set autoscale"
        Describe = "Configure Autoscale"
        Test     = { (kubectl get hpa).length -gt 1 }
        Set      = {
            kubectl autoscale deployment mics-test --min=2 --max=5 --cpu-percent=80
        }
    }
)

$azureReqs | Invoke-Requirement | Format-Checklist
$provisionReqs | Invoke-Requirement | Format-Checklist
$dockerReqs | Invoke-Requirement | Format-Checklist
$k8sReqs | Invoke-Requirement | Format-Checklist