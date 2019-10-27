$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$OutputDir = "$PSScriptRoot/out"

Import-Module -Name "./modules/jaw"

"Requirements" | % {
    Install-Module -Name $_ -Force
    Import-Module -Name $_
}

# Auth Azure and gather subscription secrets
$azureReqs = @(
    @{
        Name     = "Azure Login"
        Describe = "Authenticate Azure Session"
        Test     = { [boolean] (az account show) }
        Set      = { az login }
    }
)

# Detect global infra
$globalReqs = @(
    @{
        Name     = "Set Terraform Location"
        Describe = "Enter Terraform Context"
        Test     = { (Get-Location).Path -eq "$RepoRoot/tf/global" }
        Set      = { Set-Location "$RepoRoot/tf/global" }
    },
    @{
        Name     = "Terraform init"
        Describe = "Initialize terraform environment"
        Test     = { Test-Path "$PSScriptRoot/tf/global/.terraform" }
        Set      = {
            terraform init
            terraform refresh
        }
    },
    @{
        Name     = "Terraform plan"
        Describe = "Plan terraform environment"
        Test     = { Test-Path "$OutputDir/global.plan" }
        Set      = {
            New-Item -Path "$OutputDir" -ItemType Directory -Force
            terraform plan -out "$OutputDir/global.plan"
        }
    },
    @{
        Name     = "Terraform Apply"
        Describe = "Apply Terraform plan"
        Set      = { terraform apply "$OutputDir/global.plan" }
    },
    @{
        Name     = "Generate Config"
        Describe = "Generate Global Config File"
        Test     = { Test-Path "$OutputDir/global" }
        Set      = {
            terraform refresh
            terraform output | Out-File "$OutputDir/global" }
    },
    @{
        Name     = "Restore Repo Directory"
        Describe = "Restore Location"
        Test     = { (Get-Location).Path -eq $RepoRoot }
        Set      = { Set-Location $RepoRoot }
    }
)

$persistReqs = @(
    @{
        Name     = "Load Config"
        Describe = "Load State Config"
        Set      = {
            Get-Content $OutputDir/global | % {
                $varline = $_ -split " = "
                [Environment]::SetEnvironmentVariable($varline[0], $varline[1])
            }

            $env:AZURE_STORAGE_ACCOUNT = "sbdtfstorage"
            $env:AZURE_STORAGE_KEY = $env:TF_storage_key
        }
    },
    @{
        Name     = "Create State Container"
        Describe = "Create State Container"
        Test     = { (az storage container exists --name tfstate | ConvertFrom-Json).exists }
        Set      = {
            az storage container create --name tfstate
        }
    },
    @{
        Name     = "Upload State"
        Describe = "Upload State"
        Test     = { (az storage blob exists --container-name tfstate --name terraform.tfstate | ConvertFrom-Json).exists }
        Set      = {
            az storage blob upload --container-name tfstate --name terraform.tfstate --file $RepoRoot/tf/global/terraform.tfstate
        }
    }
)

$azureReqs | Invoke-Requirement | Format-Checklist
$globalReqs | Invoke-Requirement | Format-Checklist
$persistReqs | Invoke-Requirement | Format-Checklist

# Set secrets
"TF-sql-user", "TF-sql-password" `
| % {
    # This is an ugly hack because powershell doesn't have closures
    New-Variable -Name "secretname" -Value $_ -Scope "local" -Force
    @{
        Describe = "Secret '$secretname' exists"
        Set      = {
            az keyvault secret set --name $secretname --vault-name $env:kv_name --value ([guid]::newguid()).Guid
        }
    } | Invoke-Requirement | Format-Checklist
}

# Set SSH keys
@(
    @{
        Describe = "Generate SSH Keys"
        Test     = { (Test-Path ./key) -and (Test-Path ./key.pub) }
        Set      = {
            ssh-keygen -t rsa -b 4096 -N '""' -f key
        }
    },
    @{
        Describe = "Upload SSH Keys"
        Set      = {
            az keyvault secret set --name ssh-private-key --vault-name $env:kv_name --value $(Get-Content ./key -Raw)
            az keyvault secret set --name ssh-public-key --vault-name $env:kv_name --value $(Get-Content ./key.pub -Raw)
        }
    },
    @{
        Describe = "Clean up Keys"
        Test     = { -not (Test-Path ./key) -and -not (Test-Path ./key.pub) }
        Set      = {
            rm ./key
            rm ./key.pub
        }
    }
) | Invoke-Requirement | Format-Checklist