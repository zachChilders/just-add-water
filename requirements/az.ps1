<#
.SYNOPSIS
  Az CLI is configured for the specified cluster
#>

$RepoRoot = "$PSScriptRoot/.."
$SystemConfigPath = "$RepoRoot/water.json"

$SystemConfig = Get-Content $SystemConfigPath -Raw | ConvertFrom-Json
$SubscriptionId = $SystemConfig.AzureSubscriptionId

@{
  Describe = "Az CLI is installed (must be installed manually)"
  Test     = { Get-Command "az" -ErrorAction SilentlyContinue }
}

@{
  Describe = "Az CLI is logged in"
  Test     = {
    $subscription = az account show | ConvertFrom-Json
    $subscription.id -eq $SubscriptionId -and $subscription.state -eq "Enabled"
  }
  Set      = { az login --subscription $SubscriptionId }
}
