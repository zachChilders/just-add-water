$RepoRoot = "$PSScriptRoot/../.."
$OutDir = "$RepoRoot/out"

# Delete k8s Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? {$_.Name -like "sbd"}).name
az group delete --name $azName -y


# Delete Infrastructure Resource Group
$azResourceGroups = (az group list) | ConvertFrom-Json
$azName = ($azResourceGroups | ? {$_.Name -like "MC_sbd_sbd_southcentralus"}).name
az group delete --name $azName -y

# Remove Terraform State
rm -rf ./.terraform
rm terraform.tfstate
rm terraform.tfstate.backup

# Delete just-add-water files
rm $OutDir/azurek8s
rm $OutDir/out.plan
rm $OutDir/k8s.json
rm $OutDir/pod.yml

Set-Location $RepoRoot