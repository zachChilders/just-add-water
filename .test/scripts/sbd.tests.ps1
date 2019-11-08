#$RepoRoot = "$PSScriptRoot/../.."

Describe "Validate Deploy.ps1" {
    BeforeAll {
        git submodule update --init
        & "$RepoRoot/deploy.ps1" -EnclaveName "micssbdtest"
    }
    AfterAll {
        & "$RepoRoot/tf/enclave/clean.ps1" -EnclaveName "micssbdtest"
    }
    It "Created Azure Resources" {
        az group exists --name micssbdtest | Should -Be "true"
    }
    It "Renders an Actual Page" {
        Start-Sleep -Seconds 90 # Ensure DNS has time to propagate
        (Invoke-WebRequest micssbdtest.southcentralus.cloudapp.azure.com).StatusCode | Should -Be 200
    }
    It "Can Connect to Resources" {
        [boolean] (kubectl get deployment) | Should -BeTrue
    }
}