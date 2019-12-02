$ErrorActionPreference = "Stop"

# Class to hold Docker structure
class Docker {
  [string] $Name
  [string] $ImageName
  [string] $Path
  [string[]] $Ports
  [boolean] $Frontend # To identify which port serves traffic
}

<#
.SYNOPSIS
  Transforms data from a hashtable into a config template.
.NOTES
  Works on any type of config.  Replaces "{{varname}}" => $varname.
#>
function Expand-Template {
  [CmdletBinding()]
  [OutputType([String])]
  Param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Template,
    [Parameter(Mandatory)]
    [hashtable] $Data
  )

  $instance = $Template
  $data.keys | % { $instance = $instance -replace "{{$_}}", $Data[$_] }
  $instance
}

<#
.SYNOPSIS
  Generates a list of container names for later usage.
#>
function Get-ContainerNames {
  param(
    [string] $AppPath
  )
  Get-ChildItem -Path $AppPath -Filter "*dockerfile*" -Recurse
}


function Get-KustomizePackages {
  param(
    [string] $AppPath
  )
  Get-ChildItem -Path $AppPath -Filter "kustomization-template.yaml" -Recurse
}

<#
.SYNOPSIS
  Generates a config JSON based on contents of an /app folder.
.NOTES
  Searches for dockerfiles and saves information about them for later use.
#>
function Set-k8sConfig {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $AppPath,
    [string] $OutPath
  )
  # parse each Dockerfile in to a K8S JSON
  # we only check for top level dockerfiles right now.
  Get-KustomizePackages | % {
    # Full File Name
    $Name = $_.FullName
    # Parent Directory
    $Path = $_.Directory
    # This resolves to the folder directly beneath /app
    $ImageName = ($Path -split "/")[-1]
    # Query inactive container for config
    $Config = docker inspect mics233.azurecr.io/$ImageName --format="{{json .Config}}"
    # Extract port numbers out of config
    if (-not [string]::IsNullOrEmpty($Config)) {
      $Ports = ($Config | ConvertFrom-Json -AsHashtable).ExposedPorts.Keys | % { ($_ -split "/")[0] }
    }
    else {
      $Ports = 80
    }

    # Build a model for serialization
    [Docker] @{
      Name      = $Name
      ImageName = $ImageName
      Path      = $Path
      Ports     = $Ports
      Frontend  = $false
    }
  } `
  | ConvertTo-Json `
  | Out-File "$OutPath/k8s.json"
}
