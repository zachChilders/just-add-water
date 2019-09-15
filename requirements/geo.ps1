<#
.SYNOPSIS
  Defines Requirements for a compliance zone
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

Import-Module "$RepoRoot/jawctl.psd1"

# apply terraform
$variables = Select-Config @PSBoundParameters
&"$RequirementsRoot/terraform" -Name "geo" -Variables $variables

# deploy each region under this geo
Select-Cluster @PSBoundParameters `
| % { Split-Cluster -Set Region -Cluster $_ } `
| Sort-Object -Unique `
| % { &"$RequirementsRoot/region" -Ring $Ring -Geo $Geo -Region $_ -Cluster "*" }
