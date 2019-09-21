$ErrorActionPreference = "Stop"

$RepoRoot = "$PSScriptRoot/.."

# Class to hold Docker structure
class Docker {
    [string] $Name
    [string] $ImageName
    [string] $Path
    [hashtable] $Commands
    [boolean] $Frontend # To identify which port serves traffic
}

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

function Set-k8sConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$AppPath = "$RepoRoot/app",
        [string]$OutPath = "$RepoRoot/out"
    )

    # parse each Dockerfile in to a K8S JSON
    # we only check for top level dockerfiles right now.
    Get-ChildItem -Filter "*dockerfile*" -Recurse `
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