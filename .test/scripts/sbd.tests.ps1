$RepoRoot = "$PSScriptRoot/../.."
$EnclaveName = "micssbdtest$((([guid]::newguid().guid) -replace "-").substring(1,5))"
$HostName = "$EnclaveName.southcentralus.cloudapp.azure.com"

Describe "Validate Deploy.ps1" {
    BeforeAll {
        git submodule update --init
        & "$RepoRoot/deploy.ps1" -EnclaveName $EnclaveName -HostName $HostName
    }
    AfterAll {
        & "$RepoRoot/tf/enclave/clean.ps1" -EnclaveName $EnclaveName
    }
    It "Created Azure Resources" {
        az group exists --name $EnclaveName | Should -Be "true"
    }
    It "Renders an Actual Page" {
        Start-Sleep -Seconds 300 # Ensure DNS has time to propagate
        (Invoke-WebRequest $HostName -SkipCertificateCheck).StatusCode | Should -Be 200
    }
    It "Can Connect to Resources" {
        [boolean] (kubectl get deployment) | Should -BeTrue
    }
}