<#
.SYNOPSIS
  Defines a region
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
&"$RequirementsRoot/terraform" -Name "region" -Variables $variables

# deploy each cluster under this region
Select-Cluster @PSBoundParameters `
| % { Split-Cluster -Set Cluster -Cluster $_ } `
| Sort-Object -Unique `
| % { &"$RequirementsRoot/cluster" -Ring $Ring -Geo $Geo -Region $Region -Cluster $_ }
