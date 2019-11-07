$RepoRoot = "$PSScriptRoot/../.."
$ScriptsRoot = "$RepoRoot/.test/scripts"
$OutRoot = "$ScriptsRoot/../out"

Describe "Validate Deploy.ps1" {
    BeforeAll {
        & "$RepoRoot/deploy.ps1"
    }
    AfterAll {
        & "$RepoRoot/tf/enclave/clean.ps1"
    }
    It "Created Azure Resources" {}
    It "Renders an Actual Page" {}
    It "Can Connect to Resources" {}
    It "Ran All Hardening Scripts" {}
}