
$RepoRoot = "$PSScriptRoot/.."
$ClustersRoot = "$RepoRoot/clusters"

$Index = @{
  Ring    = 0
  Geo     = 1
  Region  = 2
  Cluster = 3
}

function Add-Cluster {
  throw "NYI"
}

function Remove-Cluster {
  throw "NYI"
}

function Select-Cluster {
  Param(
    [ValidateNotNullOrEmpty()]
    [string] $Ring = "*",
    [ValidateNotNullOrEmpty()]
    [string] $Geo = "*",
    [ValidateNotNullOrEmpty()]
    [string] $Region = "*",
    [ValidateNotNullOrEmpty()]
    [string] $Cluster = "*"
  )

  Get-ChildItem "$ClustersRoot/$Ring-$Geo-$Region-$Cluster.json" | % BaseName
}

function Split-Cluster {
  Param(
    [ValidateSet("Ring", "Geo", "Region", "Cluster")]
    [string]$Set,
    [ValidateNotNullOrEmpty()]
    [string]$Cluster
  )

  ($Cluster -split "-")[$Index[$Set]]
}

Export-ModuleMember -Function *
