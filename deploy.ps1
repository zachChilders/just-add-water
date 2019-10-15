$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$OutputDir = "$PSScriptRoot/out"

# TODO: Set these better
$tf_share = "zachterraformstorage"
$kv_name = "mics-kv"
$acr_name = "mics233.azurecr.io"

Import-Module -Name "./modules/jaw"

"Requirements" | % {
    if (-not (Get-InstalledModule  $_)) {
        Install-Module $_ -Force
    }
    Import-Module $_
}

# Auth Azure and gather subscription secrets
$azureReqs = @(
    @{
        Name     = "Azure Login"
        Describe = "Authenticate Azure Session"
        Test     = { [boolean] (az account show) }
        Set      = { az login }
    },
    @{  # This could be done idempotently with a test,
        # but refreshing the secrets every run allows for
        # new secrets to be added easily
        Name     = "Keyvault Secrets"
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
        Name     = "Terraform init"
        Describe = "Initialize terraform environment"
        Test     = { Test-Path "$PSScriptRoot/tf/.terraform/terraform.tfstate" }
        Set      = {
            Set-Location -Path "tf"
            terraform init -backend-config="storage_account_name=$($tf_share)" `
                -backend-config="container_name=tfstate" `
                -backend-config="access_key=$($env:terraform_storage_key)" `
                -backend-config="key=mics.tfstate"

            # Ensure state is synchronized across deployments with production
            terraform refresh
        }
    },
    @{
        Name     = "Terraform plan"
        Describe = "Plan terraform environment"
        Test     = { Test-Path "$OutputDir/out.plan" }
        Set      = {
            New-Item -Path "$OutputDir" -ItemType Directory -Force
            terraform plan -out "$OutputDir/out.plan"
        }
    },
    @{
        Name     = "Terraform Apply"
        Describe = "Apply Terraform plan"
        Test     = { Test-Path "$OutputDir/azurek8s" }
        Set      = {
            terraform apply "$OutputDir/out.plan" | Write-Information
            terraform output kube_config | Out-File "$OutputDir/azurek8s"
            Set-Location $RepoRoot
        }
    }
)

# Docker cooking
$dockerReqs = @(
    @{
        Name     = "Generate Config File"
        Describe = "Generate JSON"
        Set      = {
            $DockerImages = az acr repository list -n mics233 -o json | ConvertFrom-Json
            Get-ContainerNames | % {
                if ($ImageName -in $DockerImages) { docker pull mics233.azurecr.io/$ImageName }
            }
            Set-k8sConfig -AppPath "./app" -OutPath "./out"
        }
    },
    @{
        Name     = "Build Docker Containers"
        Describe = "Build all containers"
        Set      = {
            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $list | % { docker build -t "$acr_name/$($_.ImageName)" -f $_.Name $_.Path }
        }
    },
    @{
        Name     = "Push Containers"
        Describe = "Push all containers"
        Set      = {
            docker login $acr_name -u mics233 -p $env:acrpassword

            $list = Get-Content ./out/k8s.json | ConvertFrom-Json
            $list | % { docker push "$acr_name/$($_.ImageName)" }
        }
    }
)

# Kubernetes Deployment
$k8sReqs = @(
    @{
        Name     = "Load Config"
        Describe = "Load k8s config"
        Set      = {
            $env:KUBECONFIG = "./out/azurek8s"
        }
    },
    @{
        Name     = "Generate pod.yml"
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
        Name     = "Deploy Application"
        Describe = "Application deployment"
        Set      = {
            kubectl apply -f $OutputDir/pod.yml
        }
    },
    @{
        Name     = "Set autoscale"
        Describe = "Configure Autoscale"
        Test     = { kubectl get hpa }
        Set      = {
            kubectl autoscale deployment pegasus --min=2 --max=5 --cpu-percent=80
        }
    },
    @{
        Name     = "Harden Cluster"
        Describe = "Apply security policy"
        Test     = { kubectl get psp } # Improve tests
        Set      = {
            # Install the aks-preview extension
            az extension add --name aks-preview

            # Update the extension to make sure you have the latest version installed
            az extension update --name aks-preview

            # Apply default policy
            az aks update --resource-group sbd --name sbd --enable-pod-security-policy
        }
    }
)

$azureReqs | Invoke-Requirement | Format-Checklist
$tfReqs | Invoke-Requirement | Format-Checklist
$dockerReqs | Invoke-Requirement | Format-Checklist
$k8sReqs | Invoke-Requirement | Format-Checklist
