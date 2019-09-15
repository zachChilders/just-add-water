<#
.SYNOPSIS
  Runs linting and unit testing
#>

$RepoRoot = "$PSScriptRoot/.."
$AppsRoot = "$RepoRoot/apps"
$ScriptAnalyerSettingsPath = "$RepoRoot/.config/PSScriptAnalyzerSettings.psd1"
$SystemJsonPath = "$RepoRoot/water.json"
$SystemSchemaPath = "$RepoRoot/.config/water.schema.json"

Import-Module "$RepoRoot/jawctl.psd1"

@{
  Describe = "System"
  Test     = {
    $json = Get-Content $SystemJsonPath -Raw
    $schema = Get-Content $SystemSchemaPath -Raw
    Test-Json -Json $json -Schema $schema
  }
}

@{
  Describe = "Lint"
  Test     = {
    $results = Invoke-ScriptAnalyzer $RepoRoot -Settings $ScriptAnalyerSettingsPath -Recurse
    if ($results) {
      $results | Format-Table | Out-String | Write-Error
    }
    -not $results
  }
}

@{
  Describe = "Unit test"
  Test     = {
    $results = Invoke-Pester "$RepoRoot/.test" -Show None -PassThru
    $results.FailedCount -eq 0
  }
}

foreach ($app in Get-ChildItem $AppsRoot | % Name) {
  @{
    Describe = "App '$app' is valid"
    Test     = { Test-App $app }
  }
}
