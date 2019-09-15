<#
.SYNOPSIS
  Applies a terraform template
#>

Param(
  [ValidateNotNullOrEmpty()]
  [string]$Name,
  [ValidateNotNullOrEmpty()]
  [hashtable]$Variables
)

$RepoRoot = "$PSScriptRoot/.."
$TerraformRoot = "$RepoRoot/terraform"
$TemplatePath = "$TerraformRoot/$Name.tf"

@{
  Describe = "Apply '$Name' terraform model"
  Set      = {
    # TODO: deploy $TemplatePath with $Variables
    $TemplatePath
  }
}

# TODO: not sure about the stuff below

@{
  Name     = "Terraform init"
  Describe = "Initialize terraform environment"
  Test     = { Test-Path "$TerraformRoot/.terraform" }
  Set      = {
    Invoke-InDirectory $TerraformRoot {
      terraform init `
        -backend-config="storage_account_name=$($tf_share)" `
        -backend-config="container_name=tfstate" `
        -backend-config="access_key=$($env:terraform_storage_key)" `
        -backend-config="key=mics.tfstate"
    }
  }
}

@{
  Name     = "Terraform plan"
  Describe = "Plan terraform environment"
  Test     = { Test-Path "$OutRoot/out.plan" }
  Set      = {
    New-Item -Path $OutRoot -ItemType Directory -Force
    terraform plan -out "$OutRoot/out.plan" | Write-Output
  }
}

@{
  Name     = "Terraform Apply"
  Describe = "Apply Terraform plan"
  Test     = { Test-Path "$OutRoot/azurek8s" } # TODO: probe infra for test
  Set      = {
    terraform apply "$OutRoot/out.plan" | Write-Information
    terraform output kube_config | Out-File ../out/azurek8s
    Set-Location -Path ".." # side effect! use Invoke-InDirectory instead
  }
}