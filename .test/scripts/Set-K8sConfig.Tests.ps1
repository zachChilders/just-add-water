
$RepoRoot = "$PSScriptRoot/../.."
$ScriptsRoot = "$RepoRoot/scripts"
$OutRoot = "$PSScriptRoot/../out"

Describe "Set-K8sConfig" {
  BeforeAll {
    &"$ScriptsRoot/Set-K8sConfig.ps1" -Path (Split-Path $OutRoot -Parent)
  }
  AfterAll {
    Remove-Item $OutRoot -Recurse -Force
  }
  It "Should create a Json for every Dockerfile" {
    Test-Path "$OutRoot/k8s.json" | Should -BeTrue
  }
  It "Json should contain string" -Skip {
    Get-Content "$OutRoot/k8s.json" -Raw | Should -Match "hello world"
  }
}
