$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$OutputDir = "$PSScriptRoot/out"

$tf_share = "sbdtfstorage"
$kv_name = "sbdvault"
$acr_name = "sbdacrglobal.azurecr.io"

Import-Module -Name "./modules/jaw"

"Requirements" | % {
    Install-Module -Name $_ -Force
    Import-Module -Name $_
}

# Auth Azure and gather subscription secrets
$azureReqs = @(
    @{
        Describe = "Authenticate Azure Session"
        Test     = { [boolean] (az account show) }
        Set      = { az login }
    },
    @{
        Describe = "Inject Secrets into Session"
        Set      = {
            $KEYVAULTNAME = $kv_name
            $SECRETS = ( $(az keyvault secret list --vault-name $KEYVAULTNAME | jq '.[].id' -r | sed 's/.*\/\([^/]\+\)$/\1/') )
            $SECRETS | % {
                $SECRET = $(az keyvault secret show --name $_ --vault-name $KEYVAULTNAME | jq '.value' -r)
                $NAME = $_.Replace("-", "_")
                [Environment]::SetEnvironmentVariable($NAME, $SECRET)
            }
        }
    }
)

# Provision Infra
$tfReqs = @(
    @{
        Describe = "Enter Terraform Context"
        Test     = { (Get-Location).Path -eq "$RepoRoot/tf/enclave" }
        Set      = { Set-Location "$RepoRoot/tf/enclave" }
    },
    @{
        Describe = "Initialize Terraform Environment"
        Test     = { Test-Path "$PSScriptRoot/tf/enclave/.terraform/terraform.tfstate" }
        Set      = {
            terraform init -backend-config="storage_account_name=$($tf_share)" `
                -backend-config="container_name=tfstate" `
                -backend-config="access_key=$($env:tf_storage_key)" `
                -backend-config="key=mics.tfstate"

            # Ensure state is synchronized across deployments with production
            terraform refresh
        }
    },
    @{
        Describe = "Plan terraform environment"
        Test     = { Test-Path "$OutputDir/out.plan" }
        Set      = {
            New-Item -Path "$OutputDir" -ItemType Directory -Force
            terraform plan -out "$OutputDir/out.plan" -refresh=true
        }
    },
    @{
        Describe = "Apply Terraform plan"
        Test     = { [boolean] (terraform output host) }
        Set      = { terraform apply "$OutputDir/out.plan" }
    },
    @{
        Describe = "Generate k8s File"
        Test     = { Test-Path "$OutputDir/azurek8s" }
        Set      = { terraform output kube_config | Out-File "$OutputDir/azurek8s" }
    },
    @{
        Describe = "Restore Location"
        Test     = { (Get-Location).Path -eq $RepoRoot }
        Set      = { Set-Location $RepoRoot }
    }
)

# Docker cooking
$dockerReqs = @(
    @{
        Describe = "Generate JSON"
        Set      = {
            $DockerImages = az acr repository list -n sbdacrglobal -o json | ConvertFrom-Json
            Get-ContainerNames | % {
                $ImageName = $_.ImageName
                if ($ImageName -in $DockerImages) { docker pull $env:acr_login_server/$ImageName }
            }
            Set-k8sConfig -AppPath "./app" -OutPath "./out"
        }
    },
    @{
        Describe = "Build all containers"
        Set      = {
            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $list | % { docker build -t "$acr_name/$($_.ImageName)" -f $_.Name $_.Path }
        }
    },
    @{
        Describe = "Push all containers"
        Set      = {
            docker login $acr_name -u $env:acr_admin -p $env:acr_password | Out-Null

            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $list | % { docker push "$acr_name/$($_.ImageName)" }
        }
    }
)

# Kubernetes Deployment
$k8sReqs = @(
    @{
        Describe = "Load k8s config"
        Set      = {
            $env:KUBECONFIG = "./out/azurek8s"
        }
    },
    @{
        Describe = "Generate pod.yml"
        Test     = { Test-Path $OutputDir/pod.yml }
        Set      = {
            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $deploy_template = (Get-Content ./templates/k8s/deployment.yml | Join-String -Separator "`n" )
            $service_template = (Get-Content ./templates/k8s/service.yml | Join-String -Separator "`n")

            $list | % {
                $deploy_data = @{
                    "deploy_name" = "pegasus"
                    "image_name"  = $_.ImageName
                    "cr_name"     = $acr_name
                    "port"        = $_.Ports
                }
                Expand-Template -Template $deploy_template -Data $deploy_data | Out-File $OutputDir/pod.yml -Append
                "---" | Out-File $OutputDir/pod.yml -Append
            }

            $service_data = @{
                "service_name" = "pegasus"
                "port"         = 80 # This needs to enforce 443 - See issue #41
            }
            Expand-Template -Template $service_template -Data $service_data | Out-File $OutputDir/pod.yml -Append
        }
    },
    @{
        Describe = "Application deployment"
        Set      = {
            kubectl apply -f $OutputDir/pod.yml
        }
    },
    @{
        Describe = "Configure Autoscale"
        Test     = { kubectl get hpa }
        Set      = {
            kubectl autoscale deployment pegasus --min=2 --max=5 --cpu-percent=80
        }
    },
    @{
        Describe = "Deploy kured"
        Test     = { [boolean] (kubectl describe nodes | grep kured) }
        Set      = {
            kubectl apply -f https://github.com/weaveworks/kured/releases/download/1.2.0/kured-1.2.0-dockerhub.yaml
        }
    },
    @{
        Describe = "Create DNS Name"
        Test     = {
            $rg = "MC_sbd_sbd_southcentralus"
            $name = (az network public-ip list -g $rg | ConvertFrom-Json).name
            (az network public-ip show -g $rg -n $name | ConvertFrom-Json).dnssettings.domainnamelabel -eq "mics-sbd"
        }
        Set      = {
            $rg = "MC_sbd_sbd_southcentralus"
            $name = (az network public-ip list -g $rg | ConvertFrom-Json).name
            az network public-ip update -g $rg -n $name --dns-name mics-sbd
        }
    },
    @{
        Describe = "Update Traffic Manager"
        Test     = {
            $rg = "sbd-global"
            (az network traffic-manager endpoint list -g $rg --profile-name "sbd-atm" | ConvertFrom-Json).name -eq "mics-sbd"
        }
        Set      = {
            $rg = "sbd-global"
            $iprg = "MC_sbd_sbd_southcentralus"
            $id = (az network public-ip list -g $iprg | ConvertFrom-Json).id
            az network traffic-manager endpoint create -g $rg --profile-name "sbd-atm" -n mics-sbd --type azureEndpoints --target-resource-id $id --endpoint-status enabled --weight 1
        }
    }
    #,
    # @{
    #     Describe = "Apply security policy"
    #     Test     = { kubectl get psp } # Improve tests
    #     Set      = {
    #         # Install the aks-preview extension
    #         az extension add --name aks-preview

    #         # Update the extension to make sure you have the latest version installed
    #         az extension update --name aks-preview

    #         # Apply default policy
    #         az aks update --resource-group sbd --name sbd --enable-pod-security-policy
    #     }
    # }
)

$azureReqs | Invoke-Requirement | Format-Checklist
$tfReqs | Invoke-Requirement | Format-Checklist
$dockerReqs | Invoke-Requirement | Format-Checklist
$k8sReqs | Invoke-Requirement | Format-Checklist
