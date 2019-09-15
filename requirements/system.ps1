<#
.SYNOPSIS
  Defines our entire system
#>

Param(
  [ValidateNotNullOrEmpty()]
  [string] $Ring,
  [ValidateNotNullOrEmpty()]
  [string] $Geo,
  [ValidateNotNullOrEmpty()]
  [string] $Region,
  [ValidateNotNullOrEmpty()]
  [string] $Cluster
)

$RepoRoot = "$PSScriptRoot/.."
$RequirementsRoot = "$RepoRoot/requirements"

&"$RequirementsRoot/az" @PSBoundParameters

@{
  Name     = "Keyvault Secrets"
  Describe = "Inject Secrets into Session"
  Set      = {
    # TODO: use pwsh
    $KEYVAULTNAME = $kv_name
    $SECRETS = ( $(az keyvault secret list --vault-name $KEYVAULTNAME | jq '.[].id' -r | sed 's/.*\/\([^/]\+\)$/\1/') )
    $SECRETS | % {
      $SECRET = $(az keyvault secret show --name $_ --vault-name $KEYVAULTNAME | jq '.value' -r)
      $NAME = $_.Replace("-", "_")
      [Environment]::SetEnvironmentVariable($NAME, $SECRET)
    }
  }
}

# deploy each geo under this ring
Select-Cluster @PSBoundParameters `
| % { Split-Cluster -Set Ring -Cluster $_ } `
| Sort-Object -Unique `
| % { &"$RequirementsRoot/ring" -Ring $_ -Geo * -Region * Cluster * }
