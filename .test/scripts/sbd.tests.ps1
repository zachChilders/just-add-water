$RepoRoot = "$PSScriptRoot/../.."

Describe "Validate Deploy.ps1" {
    BeforeAll {
        git submodule update --init
        & "$RepoRoot/deploy.ps1"
    }
    AfterAll {
        & "$RepoRoot/tf/enclave/clean.ps1"
    }
    It "Created Azure Resources" {
        az group exists --name sbd | Should -Be "true"
    }
    It "Renders an Actual Page" {
        Start-Sleep -Seconds 60 # Ensure DNS has time to propagate
        (Invoke-WebRequest sbd.trafficmanager.net).StatusCode | Should -Be 200
    }
    It "Can Connect to Resources" {
        [boolean] (kubectl get deployment) | Should -BeTrue
    }
}