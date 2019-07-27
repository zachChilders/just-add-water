#!/bin/bash

az login

KEYVAULTNAME="mics-kv"
SECRETS=( $(az keyvault secret list --vault-name $KEYVAULTNAME | jq '.[].id' -r | sed 's/.*\/\([^/]\+\)$/\1/') )
for NAME in ${SECRETS[@]}; do
    SECRET=$(az keyvault secret show --name $NAME --vault-name $KEYVAULTNAME | jq '.value' -r)
    export NAME=$(echo $NAME | tr - _)
    export $NAME=$SECRET
done

export TF_VAR_client_id=$ARM_CLIENT_ID
export TF_VAR_client_secret=$ARM_CLIENT_SECRET