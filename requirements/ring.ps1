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

Import-Module "$RepoRoot/jawctl.psd1"

# apply terraform
$variables = Select-Config @PSBoundParameters
&"$RequirementsRoot/terraform" -Name "ring" -Variables $variables

# deploy each geo under this ring
Select-Cluster @PSBoundParameters `
| % { Split-Cluster -Set Geo -Cluster $_ } `
| Sort-Object -Unique `
| % { &"$RequirementsRoot/geo" -Ring $Ring -Geo $_ -Region * -Cluster * }
