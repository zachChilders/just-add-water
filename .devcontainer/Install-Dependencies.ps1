$ErrorActionPreference = "STOP"

# Bootstrap Requirements

Install-Module Requirements -Force
Import-Module Requirements

$azurecli = @(
    @{
        Describe = "Install Azure CLI"
        Test     = { (which az).length -gt 0 }
        Set      = { curl -sL https://aka.ms/InstallAzureCLIDeb | bash } # TODO: Compare SHA256 to ensure this is correct
    }
)

$terraform = @(
    @{
        Describe = "Download Terraform"
        Test     = { Test-Path -Path ./terraform.zip }
        Set      = {
            # TODO: Compare SHA256 to ensure this is correct
            Invoke-WebRequest "https://releases.hashicorp.com/terraform/0.12.7/terraform_0.12.7_linux_amd64.zip" `
                -OutFile ./terraform.zip
        }
    },
    @{
        Describe = "Install Terraform"
        Test     = { Test-Path -Path ./usr/local/bin/terraform }
        Set      = {
            Expand-Archive -Path ./terraform.zip -DestinationPath ./terraform
            chmod +x /terraform/terraform
            Move-Item /terraform/terraform /usr/local/bin/terraform
            Remove-Item -Path ./terraform.zip
            Remove-Item -Path ./terraform
        }
    }
)

$kubectl = @(
    @{
        Describe = "Install Kubectl"
        Test     = { Test-Path -Path ./usr/local/bin/kubectl }
        Set      = { az aks install-cli }
    }
)

$azurecli | Invoke-Requirement | Format-Verbose
$terraform | Invoke-Requirement | Format-Verbose
$kubectl | Invoke-Requirement | Format-Verbose