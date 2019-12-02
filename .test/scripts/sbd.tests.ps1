$RepoRoot = "$PSScriptRoot/../.."
$EnclaveName = "micssbdtest$((([guid]::newguid().guid) -replace "-").substring(1,5))"

Describe "Validate Deploy.ps1" {
    BeforeAll {
        git submodule update --init
        & "$RepoRoot/deploy.ps1" -EnclaveName $EnclaveName
    }
    AfterAll {
        & "$RepoRoot/tf/enclave/clean.ps1" -EnclaveName $EnclaveName
    }
    It "Created Azure Resources" {
        az group exists --name $EnclaveName | Should -Be "true"
    }
    It "Renders an Actual Page" {
        Start-Sleep -Seconds 90 # Ensure DNS has time to propagate
        (Invoke-WebRequest "$($EnclaveName).southcentralus.cloudapp.azure.com").StatusCode | Should -Be 200
    }
    It "Can Connect to Resources" {
        [boolean] (kubectl get deployment) | Should -BeTrue
    }
}