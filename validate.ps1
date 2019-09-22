
$RepoRoot = "$PSScriptRoot/.."

# install and import prerequisite modules
"PSScriptAnalyzer", "Requirements" `
| ? { -not (Get-InstalledModule $_) } `
| % {
  Install-Module $_ -Scope CurrentUser
  Import-Module $_
}

# validate the repo
@(
  @{
    Describe = "Lint"
    Test     = {
      $results = Invoke-ScriptAnalyzer $RepoRoot -Recurse
      if ($results) {
        $results | Format-Table | Out-String | Write-Error
      }
      -not $results
    }
  },
  @{
    Describe = "Unit test"
    Test     = {
      $results = Invoke-Pester "$RepoRoot/.test" -PassThru
      $results.FailedCount -eq 0
    }
  }
) `
| Invoke-Requirement `
| Format-CallStack
