$ErrorActionPreference = "Stop"

# Class to hold Docker structure
class Docker {
    [string] $Name
    [string] $ImageName
    [string] $Path
    [hashtable] $Commands
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
        # parse each Dockerfile directive into @{$command => $args}
        $commands = @{ }
        Get-Content $_.FullName `
        | ? { $_ -notmatch "^\s*$" } `
        | % {
            # First word is cmd, all else is args
            $words = $_ -split " "
            $cmd = $words | Select -First 1
            $args = $words | Select -Skip 1

            # set/append args in the command hash
            if (-not [string]::IsNullOrEmpty($cmd)) {
                $commands[$cmd] += $args
            }
        }
        [Docker] @{
            Name      = $_.FullName
            ImageName = $_.FullName.Split("/")[4].ToLower() # the foldername after /app
            Path      = $_.DirectoryName
            Commands  = $commands
            Frontend  = $false
        }
    } `
    | ConvertTo-Json `
    | Out-File "$OutPath/k8s.json"
}