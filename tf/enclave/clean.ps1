$RepoRoot = "$PSScriptRoot/../.."
$OutDir = "$RepoRoot/out"

# Delete k8s Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? { $_.Name -like "sbd" }).name
az group delete --name $azName -y


# Delete Infrastructure Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? { $_.Name -like "MC_sbd_sbd_southcentralus" }).name
az group delete --name $azName -y

# Delete TM Endpoint
az network traffic-manager endpoint delete -g "sbd-global" --profile-name "sbd-atm" --type "azureEndpoints" --name "mics-sbd"

# Delete just-add-water files
Remove-Item -Recurse "./.terraform" -Force

"./terraform.tfstate",
"./terraform.tfstate.backup",
"$OutDir/azurek8s",
"$OutDir/out.plan",
"$OutDir/k8s.json",
"$OutDir/pod.yml" | % {
    Remove-Item $_ | Out-Null
}

Set-Location $RepoRoot