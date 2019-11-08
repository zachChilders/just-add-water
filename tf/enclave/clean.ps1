param(
    [string]$EnclaveName = "sbd"
)

$RepoRoot = "$PSScriptRoot/../.."
$OutDir = "$RepoRoot/out"

# Delete k8s Resource Group
az group delete --name $EnclaveName -y


# Delete Infrastructure Resource Group
az group delete --name "MC_$($EnclaveName)_$($EnclaveName)_southcentralus" -y

# Delete TM Endpoint
az network traffic-manager endpoint delete -g "sbd-global" --profile-name "sbd-atm" --type "azureEndpoints" --name $EnclaveName

# Delete just-add-water files

"./terraform.tfstate",
"./terraform.tfstate.backup",
"$OutDir/azurek8s",
"$OutDir/$EnclaveName.plan",
"$OutDir/k8s.json",
"$OutDir/pod.yml" | % {
    Remove-Item $_ -Force | Out-Null
}

Set-Location $RepoRoot

exit(0)