
Import-Module "$PSScriptRoot/utils.psm1"

$AppsRoot = "$RepoRoot/apps"

<#
.SYNOPSIS
  Validates that an app is properly defined
#>
function Test-App {
  [CmdletBinding()]
  [OutputType([boolean])]
  Param(
    # Name of the app in the apps container
    [Parameter(Mandatory)]
    [string]$Name
  )

  $AppRoot = "$AppsRoot/$Name"
  (Test-Path $AppRoot -PathType Container) -and (Test-Path "$AppRoot/Dockerfile" -PathType Leaf)
  # TODO: validate $AppRoot/app.json against schema
}

<#
.SYNOPSIS
  Adds an app to the system
#>
function Add-App {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Mandatory)]
    [string]$RepoUrl
  )

  Invoke-InDirectory $AppsRoot {
    if ($PSCmdlet.ShouldProcess($RepoUrl, "Cloning to $AppsRoot")) {
      # TODO: add to git modules
      git clone $RepoUrl | Out-Null
      if (-not $?) {
        # TODO: Better error messages
        throw "<add-app error>"
      }
    }
  }
}

<#
.SYNOPSIS
  Removes an app from the system
#>
function Remove-App {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    # Name of the app in the apps container
    [Parameter(Mandatory)]
    [string]$Name
  )

  [ValidateScript( { Test-Path $_ } )]
  $AppRoot = "$AppsRoot/$Name"
  if ($PSCmdlet.ShouldProcess($Name, "Removing app")) {
    # TODO: remove from git modules
    Remove-Item -Path $AppsRoot -Recurse
  }
}

Export-ModuleMember -Function *
