$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$OutputDir = "$PSScriptRoot/out"
New-Item $OutputDir -ItemType Directory -Force | Out-Null

Import-Module -Name "./modules/jaw"

"Requirements" | % {
    Install-Module -Name $_ -Force
    Import-Module -Name $_
}

# Auth Azure and gather subscription secrets
Push-Namespace "Active Directory" {
    @{
        Describe = "Authenticate Azure Session"
        Test     = { [boolean] (az account show) }
        Set      = { az login }
    }
    @{
        Name     = "Export Tenant Info"
        Describe = "Exporting Tenant Information"
        Set      = {
            $az = az account show | ConvertFrom-Json
            $env:TF_VAR_tenantId = $az.tenantId
        }
    }
    @{
        Describe = "Create Service Principal"
        Test     = {
            $sp = (az ad sp list --all) | ConvertFrom-Json
            "http://sbdsp" -in $sp.servicePrincipalNames
        }
        Set      = {
            $sp = (az ad sp create-for-rbac --name http://sbdsp) | ConvertFrom-Json
            $env:TF_VAR_client_id = $sp.appId
            $env:TF_VAR_client_secret = $sp.password
        }
    }
    @{
        Describe = "Create User Group"
        Test     = {
            $azg = (az ad group list) | ConvertFrom-Json
            "sbdadmin" -in $azg.displayName
        }
        Set      = {
            $azg = (az ad group create --display-name sbdadmin --mail-nickname admins) | ConvertFrom-Json
            $env:TF_VAR_groupId = $azg.objectId
        }
    }
    @{
        Describe = "Add Self to Group"
        Test     = {
            $memberId = (az ad signed-in-user show | ConvertFrom-Json).objectId
            $groupMembers = (az ad group member list --group sbdadmin | ConvertFrom-Json).objectId
            $memberId -in $groupMembers
        }
        Set      = {
            $memberId = (az ad signed-in-user show | ConvertFrom-Json).objectid
            az ad group member add --group sbdadmin --member $memberId
        }
    }
} | Invoke-Requirement | Format-Checklist

# Detect global infra
Push-Namespace "Central Infrastructure" {
    @{
        Describe = "Enter Terraform Context"
        Test     = { (Get-Location).Path -eq "$RepoRoot/tf/global" }
        Set      = { Set-Location "$RepoRoot/tf/global" }
    }
    @{
        Describe = "Initialize Terraform Environment"
        Test     = { Test-Path "$PSScriptRoot/tf/global/.terraform" }
        Set      = {
            terraform init
            terraform refresh
        }
    }
    @{
        Describe = "Plan Terraform Environment"
        Test     = { Test-Path "$OutputDir/global.plan" }
        Set      = {
            New-Item -Path "$OutputDir" -ItemType Directory -Force
            terraform plan -out "$OutputDir/global.plan"
        }
    }
    @{
        Describe = "Apply Terraform plan"
        Set      = { terraform apply "$OutputDir/global.plan" }
    }
    @{
        Describe = "Generate Global Config File"
        Test     = { Test-Path "$OutputDir/global" }
        Set      = {
            terraform refresh
            terraform output | Out-File "$OutputDir/global"
            $env:kv_name = (terraform output kv-name)
        }
    }
    @{
        Describe = "Restore Location"
        Test     = { (Get-Location).Path -eq $RepoRoot }
        Set      = { Set-Location $RepoRoot }
    }
} | Invoke-Requirement | Format-Checklist

Push-Namespace "Persistence" {
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
            az storage container create --name tfstate | Out-Null
        }
    },
    @{
        Name     = "Upload State"
        Describe = "Upload State"
        Test     = { (az storage blob exists --container-name tfstate --name terraform.tfstate | ConvertFrom-Json).exists }
        Set      = {
            az storage blob upload --container-name tfstate --name terraform.tfstate --file $RepoRoot/tf/global/terraform.tfstate | Out-Null
        }
    }
} | Invoke-Requirement | Format-Checklist

# Set terraform secrets
Get-Content $OutputDir/global `
| % {
    $secret = $_ -split " = "
    $secretname = $secret[0]
    $secretvalue = $secret[1]
    New-Variable -Name "secretname" -Value $secretname -Scope "local" -Force
    New-Variable -Name "secretval" -Value $secretvalue -Scope "local" -Force
    @{
        Describe = "Global Secret '$secretname' exists"
        Set      = {
            az keyvault secret set --name $secretname --vault-name $env:kv_name --value $secretvalue
        }
    } | Invoke-Requirement | Format-Checklist
}

# Set environment secrets
"TF_VAR_client_id", "TF_VAR_client_secret" `
| % {
    New-Variable -Name "secretname" -Value $_ -Scope "local" -Force
    New-Variable -Name $_ -Value ([Environment]::GetEnvironmentVariable($_)) -Scope "local" -Force
    @{
        Describe = "Secret '$secretname' exists"
        Set      = {
            az keyvault secret set --name $secretname.Replace("_", "-") --vault-name $env:kv_name --value "$([Environment]::GetEnvironmentVariable($secretname))"
        }
    } | Invoke-Requirement | Format-Checklist
}

# Set SQL secrets
@(
    @{
        Describe = "Randomized Secret 'TF-VAR-sql-password' exists"
        Set      = {
            az keyvault secret set --name "TF-VAR-sql-password" --vault-name $env:kv_name --value ([guid]::newguid().Guid).replace("-", "").substring(0, 14)
        }
    }) | Invoke-Requirement | Format-Checklist


# Set SSH keys
@(
    @{
        Describe = "Generate SSH Keys"
        Test     = { (Test-Path $OutputDir/key) -and (Test-Path $OutputDir/key.pub) }
        Set      = {
            ssh-keygen -t rsa -b 4096 -N '""' -f $OutputDir/key
        }
    },
    @{
        Describe = "SSH Keys Exist"
        Set      = {
            az keyvault secret set --name TF-VAR-ssh-private-key --vault-name $env:kv_name --value $(Get-Content $OutputDir/key -Raw)
            az keyvault secret set --name TF-VAR-ssh-public-key --vault-name $env:kv_name --value $(Get-Content $OutputDir/key.pub -Raw)
        }
    },
    @{
        Describe = "Clean up Keys"
        Test     = { -not (Test-Path $OutputDir/key) -and -not (Test-Path $OutputDir/key.pub) }
        Set      = {
            rm $OutputDir/key
            rm $OutputDir/key.pub
        }
    }
) | Invoke-Requirement | Format-Checklist