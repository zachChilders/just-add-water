param(
    [string]$EnclaveName = "sbd"
)

$RepoRoot = "$PSScriptRoot/../.."
$OutputDir = "$RepoRoot/out"

# Delete k8s Resource Group
az group delete --name $EnclaveName -y

# Delete TM Endpoint
az network traffic-manager endpoint delete -g "sbd-global" --profile-name "sbd-atm" --type "azureEndpoints" --name $EnclaveName

# Cleanup Local Files
"$RepoRoot/tf/enclave/.terraform",
"$OutputDir/$EnclaveName.plan",
"$OutputDir/$EnclaveName" `
| ? {Test-Path $_} | % {Remove-Item $_ -Recurse -Force}

Set-Location $RepoRoot