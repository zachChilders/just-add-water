
Import-Module "$PSScriptRoot/utils.psm1"

$RequirementsRoot = "$RepoRoot/requirements"

<#
.SYNOPSIS
  Invokes a set of Requirements using the Requirements "Callstack" log format
.OUTPUTS
  Strings logging the execution of Requirements
#>
function Invoke-Callstack {
  [CmdletBinding(DefaultParameterSetName = "Name")]
  Param(
    # Path to a script that returns Requirements to invoke
    [Parameter(Mandatory, ParameterSetName = "Path")]
    [string]$Path,
    # An array of Requirements to invoke
    [Parameter(Mandatory, ParameterSetName = "Requirements", ValueFromPipelineByPropertyName)]
    [array]$Requirements,
    # The name of the Requirements script in the /requirements/ folder
    [Parameter(Mandatory, ParameterSetName = "Name")]
    [string]$Name,
    # Parameters to pass to the Requirements
    [hashtable]$Parameters
  )

  [ValidateNotNullOrEmpty()]
  $requirements = switch ($PSCmdlet.ParameterSetName) {
    "Path" { .$Path @Parameters }
    "Requirements" { $Requirements }
    "Name" { ."$RequirementsRoot/$Name" @Parameters }
  }

  $requirements | Invoke-Requirement | Format-CallStack
}

<#
.SYNOPSIS
  Invokes a set of Requirements with live-updating checklist of Requirements
.NOTES
  Writes to Host.  Don't use in non-interactive contexts.
#>
function Invoke-Checklist {
  [CmdletBinding(DefaultParameterSetName = "Name")]
  Param(
    # Path to a script that returns Requirements to invoke
    [Parameter(Mandatory, ParameterSetName = "Path")]
    [string]$Path,
    # An array of Requirements to invoke
    [Parameter(Mandatory, ParameterSetName = "Requirements", ValueFromPipelineByPropertyName)]
    [array]$Requirements,
    # The name of the Requirements script in the /requirements/ folder
    [Parameter(Mandatory, ParameterSetName = "Name")]
    [string]$Name,
    # Parameters to pass to the Requirements
    [hashtable]$Parameters
  )

  [ValidateNotNullOrEmpty()]
  $requirements = switch ($PSCmdlet.ParameterSetName) {
    "Path" { .$Path @Parameters }
    "Requirements" { $Requirements }
    "Name" { ."$RequirementsRoot/$Name" @Parameters }
  }

  $requirements | Invoke-Requirement | Format-Checklist
}

Export-ModuleMember -Function *
