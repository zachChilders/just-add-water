param(
    [string]$EnclaveName = "sbd"
)

# Delete k8s Resource Group
az group delete --name $EnclaveName -y

# Delete Infrastructure Resource Group
az group delete --name "MC_$($EnclaveName)_$($EnclaveName)_southcentralus" -y

# Delete TM Endpoint
az network traffic-manager endpoint delete -g "sbd-global" --profile-name "sbd-atm" --type "azureEndpoints" --name $EnclaveName


exit(0)