$RepoRoot = "$PSScriptRoot/../.."
$OutDir = "$RepoRoot/out"

# Delete Service Principal
$azId = (az ad sp list --all) | ConvertFrom-Json
$objId = ($azId | ? {$_.displayName -like "sbdsp"}).objectId
az ad sp delete --id $objId

# Delete Group
$azGroupId = (az ad group list) | ConvertFrom-Json
$objId = ($azGroupId | ? {$_.displayName -like "sbdadmin"}).objectId
az ad group delete --group $objId

# Delete Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? {$_.Name -like "sbd-global"}).name
az group delete --name $azName -y

# Delete just-add-water files
Remove-Item -Recurse ./.terraform -Force
"terraform.tfstate",
"terraform.tfstate.backup",
"$OutDir/global",
"$OutDir/global.plan" | % {
    Remove-Item $_ -Force | Out-Null
}
Set-Location $RepoRoot