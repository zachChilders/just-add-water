$ErrorActionPreference = "STOP"

# Bootstrap Requirements
if (-not (Get-Module Requirements)) {
    Install-Module Requirements -Force
}
Import-Module Requirements

# Auth Azure and gather subscription secrets
$azureReqs = @(
    @{
        Name = "Azure Login"
        Describe = "Authenticate Azure Session"
        Test = {
            (az account show | ConvertFrom-Json).state -eq "Enabled"
        }
        Set = {az login}
    },
    @{ # This could be done idempotently with a test, 
       # but refreshing the secrets every run allows for 
       # new secrets to be added easily
        Name = "Keyvault Secrets"
        Describe = "Inject Secrets into Session"
        Set = {
            $KEYVAULTNAME="mics-kv"
            $SECRETS=( $(az keyvault secret list --vault-name $KEYVAULTNAME | jq '.[].id' -r | sed 's/.*\/\([^/]\+\)$/\1/') )
            $SECRETS | % {
                $SECRET=$(az keyvault secret show --name $_ --vault-name $KEYVAULTNAME | jq '.value' -r)
                $NAME = $_.Replace("-", "_")
                [Environment]::SetEnvironmentVariable($NAME, $SECRET)
            }
        }
    }
)

# Provision Infra
$provisionReqs = @(
    @{
        Name = "Transform Environment Variables"
        Describe = "Transform Terraform Variables"
        Test = {
            $env:TF_VAR_client_id.Length -gt 0 -and $env:TF_VAR_client_secret.Length -gt 0
        }
        Set = {
            $env:TF_VAR_client_id = $env:ARM_CLIENT_ID
            $env:TF_VAR_client_secret = $env:ARM_CLIENT_SECRET
        }
    },
    @{
        Name = "Terraform init"
        Describe = "Initialize terraform environment"
        Test = {Test-Path "./.terraform"}
        Set = {
            terraform init -backend-config="storage_account_name=zachterraformstorage" `
            -backend-config="container_name=tfstate" `
            -backend-config="access_key=$($env:terraform_storage_key)" `
            -backend-config="key=mics.tfstate"
        }
    },
    @{
        Name = "Terraform plan"
        Describe = "Plan terraform environment"
        Test = {Test-Path "./out.plan"}
        Set = {
            terraform plan -out ./out.plan | Write-Host
        } 
    },
    @{
        Name = "Terraform Apply"
        Describe = "Apply terraform plan"
        Test = {Test-Path "./azurek8s"}
        Set = {
            terraform apply "./out.plan" | Write-Host
            terraform output kube_config | Out-File ./azurek8s
            $env:KUBECONFIG ="./azurek8s"
        }
    }
)

# Kubernetes setup
$k8sReqs = @(
    @{
        Name = "Deploy Application"
        Describe = "Application deployment"
        Set = {
            kubectl apply -f pod.yml
        }
    }
    @{
        Name = "Set autoscale"
        Describe = "Configure Autoscale"
        Set = {
            kubectl autoscale deployment mics-test --min=2 --max=5 --cpu-percent=80
        }
    },
    @{
        Name = "Harden Cluster"
        Describe = "Apply security policy"
        Set = {
            az aks update --resource-group azure-k8stest --name k8stest --enable-pod-security-policy
        }
    }
)

$azureReqs | Invoke-Requirement | Format-CallStack
$provisionReqs | Invoke-Requirement | Format-CallStack
$k8sReqs | Invoke-Requirement | Format-CallStack