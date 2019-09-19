$ErrorActionPreference = "Stop"

# Class to hold Docker structure
class Docker {
    [String] $Name
    [String] $Path
    [Hashtable] $Commands
    [Boolean] $Frontend # To identify which port serves traffic
}

class Deployment {
    
}

function Set-k8sConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [String]$Path = "out"
    )

    # parse each Dockerfile in to a K8S JSON
    Get-ChildItem -Filter "Dockerfile" -Recurse `
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
            if (-not [String]::IsNullOrEmpty($cmd)) {
                $commands[$cmd] += $args
            }
        }
        [Docker] @{
            Path     = $_.DirectoryName
            Name     = $_.FullName.split("/")[-2]
            Commands = $commands
            Frontend = $false
        }
    } `
    | ConvertTo-Json `
    | Out-File "$Path/k8s.json"
}