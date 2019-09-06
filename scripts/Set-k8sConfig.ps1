# Class to hold Docker structure
class Docker {
    [String] $Name
    [String] $Path
    [Hashtable] $Commands
    [Boolean] $Frontend # To identify which port serves traffic
}

# Empty k8s config
$k8sConfig = @()

# Enumerate Dockerfiles
$dockerfiles = Get-ChildItem -Recurse `
| ? { $_.Name -like "Dockerfile" }

# Build Config
ForEach ($file in $dockerfiles) {

    # Hashtable to hold commands
    $commands = @{ }

    $file `
    | % { Get-Content $_ } `
    | % {
        $line = $_ # Alias for readability
        if ($line.length -gt 0) {
            # First word is cmd, all else is args
            $cmd = $line.split(" ")[0]
            $args = $line.split(" ")[1..($line.length)]

            # Only add unique commands, otherwise append new
            if ($commands[$cmd]) {
                $commands[$cmd] += $args
            } else {
                $commands[$cmd] = @($args)
            }
        }
    }

    # Build new Docker Object and append to config
    $k8sConfig += (
        [Docker] @{
            Path     = $file
            Name     = $file.FullName.split("/")[-2]
            Commands = $commands
            Frontend = $false
        }
    )
}

# Serialize to json config
$k8sConfig | ConvertTo-Json | Out-File -FilePath "./out/k8s.json" -Force