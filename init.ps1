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

$azureReqs | Invoke-Requirement | Format-Checklist
$globalReqs | Invoke-Requirement | Format-Checklist