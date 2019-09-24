
$RepoRoot = "$PSScriptRoot/../.."
$ScriptsRoot = "$RepoRoot/.test/scripts"
$OutRoot = "$ScriptsRoot/../out"

Describe "Set-K8sConfig" {
    BeforeAll {
        Import-Module $RepoRoot/modules/jaw
        New-Item -Path $OutRoot -ItemType Directory -Force
        docker build -t "mics233.azurecr.io/data" "$RepoRoot/.test/data" -f "$RepoRoot/.test/data/test.dockerfile"
        Set-K8sConfig -AppPath "$ScriptsRoot/../data" -OutPath $OutRoot
    }
    AfterAll {
        #Remove-Item $OutRoot -Recurse -Force
    }
    It "Should create a Json" {
        Test-Path "$OutRoot/k8s.json" | Should -BeTrue
    }
    It "Json should contain string" {
        Get-Content "$OutRoot/k8s.json" -Raw | Should -Match "data"
    }
    It "Parses back to an Object" {
        Get-Content "$OutRoot/k8s.json" -Raw | ConvertFrom-Json | Select "Name" | Should -Match "test.dockerfile"
    }
}

Describe "Expand-Template" {
    BeforeAll {
        Import-Module $RepoRoot/modules/jaw
        New-Item -Path $OutRoot -ItemType Directory -Force
        $testData = @{
            "test_name" = "Hello"
        }
        Expand-Template -Template $(Get-Content "$ScriptsRoot/../data/test.yml" | Join-String -Separator "`n") -Data $testData `
        | Out-File "$OutRoot\test.yml"
    }
    AfterAll {
        #Remove-Item $OutRoot -Recurse -Force
    }
    It "Should create a yaml" {
        Test-Path "$OutRoot/test.yml" | Should -BeTrue
    }
    It "Yaml should contain string " {
        Get-Content "$OutRoot/test.yml" | Join-String -Separator "`n" | Should -Match "name: Hello"
    }
}