param(
    [string]$EnclaveName = "sbd"
)

$RepoRoot = "$PSScriptRoot/../.."
$OutDir = "$RepoRoot/out"

# Delete k8s Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? { $_.Name -like $EnclaveName }).name
az group delete --name $azName -y


# Delete Infrastructure Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? { $_.Name -like "MC_$($EnclaveName)_$($EnclaveName)_southcentralus" }).name
az group delete --name $azName -y

# Delete TM Endpoint
az network traffic-manager endpoint delete -g "sbd-global" --profile-name "sbd-atm" --type "azureEndpoints" --name $EnclaveName

# Delete just-add-water files
Remove-Item -Recurse "./.terraform" -Force

"./terraform.tfstate",
"./terraform.tfstate.backup",
"$OutDir/azurek8s",
"$OutDir/$EnclaveName.plan",
"$OutDir/k8s.json",
"$OutDir/pod.yml" | % {
    Remove-Item $_ -Force | Out-Null
}

Set-Location $RepoRoot