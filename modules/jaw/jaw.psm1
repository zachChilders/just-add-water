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
    Get-ChildItem -Path $AppPath -Filter "*dockerfile*" -Recurse `
    | % {
        $Name = $_.FullName
        $ImageName = $Name.Split("/")[4].ToLower()
        $Path = $_.Directory
        $Ports = docker inspect mics233.azurecr.io/$ImageName --format="{{json .Config}}"
        $Ports = ($Ports | ConvertFrom-Json -AsHashtable).ExposedPorts.Keys | % { ($_ -split "/")[0] }

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