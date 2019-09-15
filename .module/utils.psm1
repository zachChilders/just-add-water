
# $tf_share = "zachterraformstorage"
# $kv_name = "mics-kv"

# $RepoRoot = "$PSScriptRoot/.."
# $TerraformRoot = "$RepoRoot/tf"
# $OutRoot = "$RepoRoot/out"

function Invoke-InDirectory {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [ValidateScript( { Test-Path $_ })]
    [string]$Path,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [scriptblock]$ScriptBlock
  )

  Push-Location $Path
  try {
    &$ScriptBlock
  }
  finally {
    Pop-Location
  }
}

function Invoke-Script {
  [CmdletBinding()]
  [OutputType([boolean])]
  Param(
    [Parameter(Mandatory)]
    [scriptblock] $Script
  )

  &$Script
  if (-not $? -or $LASTEXITCODE -ne 0) {
    throw "Failed with success status '$?' and exit code '$LASTEXITCODE'"
  }
}

function Expand-Template {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Template,
    [Parameter(Mandatory)]
    [hashtable] $Data
  )

  $instance = $Template
  foreach ($key in $Data.Keys) {
    $instance = $instance -replace "{{$_}}", $Data[$_]
  }
  $instance
}

Export-ModuleMember -Function * -Variable *
