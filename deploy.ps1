param(
    [string]$EnclaveName = "sbd"
)

$ErrorActionPreference = "Stop"

# Bootstrap Dependencies
Import-Module -Name "./modules/jaw"

"Requirements" | % {
    Install-Module -Name $_ -Force
    Import-Module -Name $_
}

# Set up some directories
$RepoRoot = $PSScriptRoot
$OutputDir = "$PSScriptRoot/out"
$TemplateDir = "$RepoRoot/templates"
$SecurityDir = "$RepoRoot/security"

# Common infrastructure
$tf_share = "sbdtfstorage"
$kv_name = "sbdvault"
$acr_name = "sbdacrglobal.azurecr.io"

# Detect if we're running in a github action
$RunningInCI = ([boolean] $env:GITHUB_CLIENT_SECRET -and [boolean] $env:GITHUB_TENANT)

# Auth Azure and gather subscription secrets
$azureReqs = @(
    @{
        Describe = "Authenticate Azure Session"
        Test     = { [boolean] (az account show) }
        Set      = {
            if ($RunningInCI) {
                az login --service-principal -u "http://sbdsp" -p $env:GITHUB_CLIENT_SECRET --tenant $env:GITHUB_TENANT

                # Set up SP variables for terraform to detect headless mode
                $account = (az account list | ConvertFrom-Json)
                $env:ARM_SUBSCRIPTION_ID = $account.id
                $env:ARM_TENANT_ID = $account.tenantId
            }
            else {
                az login
            }
        }
    },
    @{
        Describe = "Inject Secrets into Session"
        Set      = {
            # Parse all variables
            $KEYVAULTNAME = $kv_name
            $SECRETS = ( $(az keyvault secret list --vault-name $KEYVAULTNAME | jq '.[].id' -r | sed 's/.*\/\([^/]\+\)$/\1/') )
            $SECRETS | % {
                $SECRET = $(az keyvault secret show --name $_ --vault-name $KEYVAULTNAME | jq '.value' -r)
                $NAME = $_.Replace("-", "_")
                [Environment]::SetEnvironmentVariable($NAME, $SECRET)
            }
            if ($RunningInCI) {
                # Set the last variables for terraform to detect headless mode
                $env:ARM_CLIENT_ID = $env:TF_VAR_client_id
                $env:ARM_CLIENT_SECRET = $env:TF_VAR_client_secret
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

            # Prep Terraform with a few last minute variables
            $env:TF_IN_AUTOMATION = "true"
            $env:TF_VAR_name_prefix = $EnclaveName
            terraform init -backend-config="storage_account_name=$($tf_share)" `
                -backend-config="container_name=tfstate" `
                -backend-config="access_key=$($env:tf_storage_key)" `
                -backend-config="key=$EnclaveName.tfstate"

            # Ensure state is synchronized across deployments with production
            terraform refresh
        }
    },
    @{
        Describe = "Plan terraform environment"
        Test     = { Test-Path "$OutputDir/$EnclaveName.plan" }
        Set      = {
            New-Item -Path "$OutputDir" -ItemType Directory -Force
            terraform plan -out "$OutputDir/$EnclaveName.plan" -refresh=true
        }
    },
    @{
        Describe = "Apply Terraform plan"
        Test     = { [boolean] (terraform output host) }
        Set      = { terraform apply "$OutputDir/$EnclaveName.plan" }
    },
    @{
        Describe = "Generate k8s File"
        Test     = { Test-Path "$OutputDir/$EnclaveName" }
        Set      = { terraform output kube_config | Out-File "$OutputDir/$EnclaveName" }
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
        Describe = "Generate Application Manifest"
        Set      = {

            # Try to pull images to save time
            $DockerImages = az acr repository list -n sbdacrglobal -o json | ConvertFrom-Json
            Get-ContainerNames | % {
                $ImageName = $_.ImageName
                if ($ImageName -in $DockerImages) { docker pull $env:acr_login_server/$ImageName }
            }

            # Generate config JSON for remaining steps to read
            Set-k8sConfig -AppPath "./app" -OutPath $OutputDir
        }
    },
    @{
        Describe = "Build all containers"
        Set      = {
            # Build all the containers found in the application manifest
            $list = Get-Content $OutputDir/k8s.json | ConvertFrom-Json
            $list | % { docker build -t "$acr_name/$($_.ImageName)" -f $_.Name $_.Path }
        }
    },
    @{
        Describe = "Push all containers"
        Set      = {
            docker login $acr_name -u $env:acr_admin -p $env:acr_password | Out-Null

            $list = Get-Content $OutputDir/k8s.json | ConvertFrom-Json
            $list | % { docker push "$acr_name/$($_.ImageName)" }
        }
    }
)

# Kubernetes Deployment
$k8sReqs = @(
    @{
        Describe = "Load k8s config"
        Set      = {
            # Kubectl reads this variable to authenticate
            $env:KUBECONFIG = "$OutputDir/$EnclaveName"
        }
    },
    @{
        Describe = "Generate pod.yml"
        Test     = { Test-Path $OutputDir/pod.yml }
        Set      = {
            # Read manifest and templates
            $list = Get-Content $OutputDir/k8s.json | ConvertFrom-Json
            $deploy_template = (Get-Content $TemplateDir/deployment.yml | Join-String -Separator "`n" )
            $service_template = (Get-Content $TemplateDir/service.yml | Join-String -Separator "`n")

            # Populate templates from manifest info
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

            # Append service info, which should always be the same.
            $service_data = @{
                "service_name" = "pegasus"
                "port"         = 80   # This needs to enforce 443 - See issue #41
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
            # These values are pretty arbitrary and not measured at all.
            kubectl autoscale deployment pegasus --min=2 --max=5 --cpu-percent=80
        }
    },
    @{
        Describe = "Deploy kured"
        Test     = { [boolean] (kubectl describe nodes | grep kured) }
        Set      = {
            # TODO: Cache kured fork
            kubectl apply -f https://github.com/weaveworks/kured/releases/download/1.2.0/kured-1.2.0-dockerhub.yaml
        }
    },
    @{
        Describe = "Create DNS Name"
        Test     = {
            # By default, there's no domain label on the public ip resource
            $rg = "MC_$($EnclaveName)_$($EnclaveName)_southcentralus"
            $name = (az network public-ip list -g $rg | ConvertFrom-Json).name
            (az network public-ip show -g $rg -n $name | ConvertFrom-Json).dnsSettings.domainNameLabel -eq "$EnclaveName"
        }
        Set      = {
            # Set the domain label - it will be $EnclaveName.$Region.cloudapp.azure.com
            $rg = "MC_$($EnclaveName)_$($EnclaveName)_southcentralus"
            $name = (az network public-ip list -g $rg | ConvertFrom-Json).name
            az network public-ip update -g $rg -n $name --dns-name "$EnclaveName"
        }
    },
    @{
        Describe = "Update Traffic Manager"
        Test     = {
            # Check for existence of our endpoint
            $rg = "sbd-global"
            (az network traffic-manager endpoint list -g $rg --profile-name "sbd-atm" | ConvertFrom-Json).name -eq $EnclaveName
        }
        Set      = {
            # Add our endpoint with a weight of 1
            $rg = "sbd-global"
            $iprg = "MC_$($EnclaveName)_$($EnclaveName)_southcentralus"
            $id = (az network public-ip list -g $iprg | ConvertFrom-Json).id
            az network traffic-manager endpoint create -g $rg --profile-name "sbd-atm" -n $EnclaveName --type azureEndpoints --target-resource-id $id --endpoint-status enabled --weight 1
        }
    },
    @{
        Describe = "Generate Security Templates"
        Test = {Test-Path "$SecurityDir/firewall.yml"}
        Set = {
            # Read block-egress template
            $firewall_template = (Get-Content $TemplateDir/block-egress.yml | Join-String -Separator "`n")

            # Populate block-egress template with service name
            $firewall_data = @{
                "service_name" = "pegasus"
            }
            Expand-Template -Template $firewall_template -Data $firewall_data | Out-File $SecurityDir/firewall.yml -Append
        }
    }
    @{
        Describe = "Security Policy Deployment"
        # TODO: Set a test here to ensure proper application
        Set      = {
            # Apply all templates in the security path
            Get-ChildItem $SecurityDir | % {
                kubectl apply -f $_
            }
        }
    }
)

# Apply all Requirements
$azureReqs | Invoke-Requirement | Format-Checklist
$tfReqs | Invoke-Requirement | Format-Checklist
$dockerReqs | Invoke-Requirement | Format-Checklist
$k8sReqs | Invoke-Requirement | Format-Checklist
