Param(
  [ValidateScript( { Test-Path $_ } )]
  [string]$Path
)

$ErrorActionPreference = "Stop"

$OutPath = "$Path/out"

# Class to hold Docker structure
class Docker {
  [String] $Name
  [String] $Path
  [Hashtable] $Commands
  [Boolean] $Frontend # To identify which port serves traffic
}

# create output path
$OutPath `
| ? { -not (Test-Path $_) } `
| % { New-Item $_ -ItemType Directory }

# parse each Dockerfile in to a K8S JSON
Get-ChildItem $Path -Filter "Dockerfile" -Recurse `
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
    $commands[$cmd] += $args
  }

  [Docker] @{
    Path     = $_.FullName
    Name     = $_.FullName.split("/")[-2]
    Commands = $commands
    Frontend = $false
  }
} `
| ConvertTo-Json `
| Out-File -FilePath "$Path/out/k8s.json" -Force
