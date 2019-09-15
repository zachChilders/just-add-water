<#
.SYNOPSIS
  Defines the configuration of kubeconfig
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

# TODO: implement
@{
  Describe = "Kubeconfig is configured for '$Ring-$Geo-$Region-$Cluster'"
  Set      = { az aks get-credentials --resource-group "$Ring-$Geo-$Region-$Cluster" }
}

# TODO: set correct namespace
