$ErrorActionPreference = "STOP"

# TODO: Set these better
$tf_share = "zachterraformstorage"
$kv_name = "mics-kv"

# Bootstrap Requirements
if (-not (Get-InstalledModule  Requirements)) {
  Install-Module Requirements -Force
}
Import-Module Requirements

# Auth Azure and gather subscription secrets
$azureReqs = @(
  @{
    Name     = "Azure Login"
    Describe = "Authenticate Azure Session"
    Test     = {
      (az account show | ConvertFrom-Json).state -eq "Enabled"
    }
    Set      = { az login }
  },
  @{ # This could be done idempotently with a test,
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
    Name     = "Transform Environment Variables"
    Describe = "Transform Terraform Variables"
    Test     = {
      $env:TF_VAR_client_id.Length -gt 0 -and $env:TF_VAR_client_secret.Length -gt 0
    }
    Set      = {
      $env:TF_VAR_client_id = $env:ARM_CLIENT_ID
      $env:TF_VAR_client_secret = $env:ARM_CLIENT_SECRET
    }
  },
  @{
    Name     = "Terraform init"
    Describe = "Initialize terraform environment"
    Test     = { Test-Path "$PSScriptRoot/tf/.terraform" }
    Set      = {
      Set-Location -Path "tf"
      terraform init -backend-config="storage_account_name=$($tf_share)" -backend-config="container_name=tfstate" -backend-config="access_key=$($env:terraform_storage_key)" -backend-config="key=mics.tfstate"
    }
  },
  @{
    Name     = "Terraform plan"
    Describe = "Plan terraform environment"
    Test     = { Test-Path "$PSScriptRoot/out/out.plan" }
    Set      = {
      New-Item -Path "$PSScriptRoot/out" -ItemType Directory -Force
      terraform plan -out "$PSScriptRoot/out/out.plan" | Write-Output
    }
  },
  @{
    Name     = "Terraform Apply"
    Describe = "Apply Terraform plan"
    Test     = { Test-Path "./out/azurek8s" } # TODO: probe infra for test
    Set      = {
      terraform apply "../out/out.plan" | Write-Information
      terraform output kube_config | Out-File ../out/azurek8s
      Set-Location -Path ".."
    }
  }
)

# TODO: Put docker in docker so you can docker while you docker
# Docker cooking
# $dockerReqs = @(
#   @{
#     Name   = "Find Docker Services"
#     Describe = "Enumerate Containers"
#     Set    = {
#       $services = Get-ChildItem ./app
#     }
#   },
#   @{
#     Name   = "Build Docker Containers"
#     Describe = "Build Docker"
#     Set    = {
#       $services = Get-ChildItem ./app
#       Write-Host $services
#     }
#   }
# )

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
# $dockerReqs | Invoke-Requirement | Format-Checklist
$k8sReqs | Invoke-Requirement | Format-Checklist