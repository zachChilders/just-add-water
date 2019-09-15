<#
.SYNOPSIS
  Defines a cluster
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

$WaitPeriodHours = 0.25

$RepoRoot = "$PSScriptRoot/.."
$AppsRoot = "$RepoRoot/apps"
$RequirementsRoot = "$RepoRoot/requirements"

# Ensure ARM env vars are set
"ARM_CLIENT_ID", "ARM_CLIENT_SECRET" `
| % {
  @{
    Describe = "Env var '$_' exists"
    Test     = { [Environment]::GetEnvironmentVariable($_) }
  }
}

# Ensure Terraform env vars are set
@(
  @{src = "ARM_CLIENT_ID"; dest = "TF_VAR_client_id" },
  @{src = "ARM_CLIENT_SECRET"; dest = "TF_VAR_client_secret" }
) `
| % {
  @{
    Describe = "Env var '$($_.dest)' is set to env var '$($_.src)'"
    Test     = { [Environment]::GetEnvironmentVariable($_.src) -eq [Environment]::GetEnvironmentVariable($_.dest) }
    Set      = {
      $srcValue = [Environment]::GetEnvironmentVariable($_.src)
      [Environment]::SetEnvironmentVariable($_.dest, $srcValue)
    }
  }
}

# Apply the terraform template
$variables = Select-Config @PSBoundParameters
&"$RequirementsRoot/terraform" -Name "cluster" -Variables $variables

# Deploy applications to this cluster
foreach ($appName in Get-ChildItem $AppsRoot | % Name) {
  &"$RequirementsRoot/application" -Name $appName
}

# Wait before deploying the next cluster
@{
  Describe = "Wait for $WaitPeriodHours hrs"
  Set      = { Start-Sleep -Seconds ($WaitPeriodHours * 60 * 60) }
}
