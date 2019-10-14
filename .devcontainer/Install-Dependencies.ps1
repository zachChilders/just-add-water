$ErrorActionPreference = "STOP"

# Bootstrap Requirements

"Requirements" | % {
    Install-Module -Name $_ -Force
    Import-Module -Name $_
}

$azurecli = @(
    @{
        Name     = "Install Azure CLI"
        Describe = "Install Azure CLI"
        Test     = { (which az).length -gt 0 }
        Set      = { curl -sL https://aka.ms/InstallAzureCLIDeb | bash } # TODO: Compare SHA256 to ensure this is correct
    }
)

$terraform = @(
    @{
        Name     = "Download Zip"
        Describe = "Download Terraform"
        Test     = { Test-Path -Path ./terraform.zip }
        Set      = {
            # TODO: Compare SHA256 to ensure this is correct
            Invoke-WebRequest "https://releases.hashicorp.com/terraform/0.12.7/terraform_0.12.7_linux_amd64.zip" `
                -OutFile ./terraform.zip
        }
    },
    @{
        Name     = "Unzip"
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
        Name     = "Install Kubectl"
        Describe = "Install Kubectl"
        Test     = { Test-Path -Path ./usr/local/bin/kubectl }
        Set      = { az aks install-cli }
    }
)

$azurecli | Invoke-Requirement | Format-CallStack
$terraform | Invoke-Requirement | Format-CallStack
$kubectl | Invoke-Requirement | Format-CallStack