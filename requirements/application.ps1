<#
.SYNOPSIS
  Defines a cluster
#>

Param(
  [ValidateNotNullOrEmpty()]
  [string]$Name
)

$RepoRoot = "$PSScriptRoot/.."
$AppsRoot = "$RepoRoot/apps"
$AppRoot = "$AppsRoot/$Name"
$KubernetesRoot = "$RepoRoot/kubernetes"

$TemplatePodPath = "$KubernetesRoot/pod.yml"
$InstancePodPath = "$AppRoot/pod.yml"

Import-Module "$RepoRoot/jawctl.psd1"

# Instantiate the pod.yml template
@{
  Describe = "Pod.yml exists"
  Test     = { Test-Path "$AppRoot/.data/pod.yml" }
  Set      = {
    Expand-Template `
      -Template (Get-Content $TemplatePodPath) `
      -Data @{ Name = $Name } `
    | Set-Content -Path $InstancePodPath -Force
  }
}

# Apply the instantiated pod.yml
@{
  Describe = "Pod '$Name' is applied"
  Set      = { kubectl apply -f $InstancePodPath }
}

# TODO: I'm pretty sure this can be in a k8s resource yml
@{
  Describe = "Pod '$Name' can autoscale"
  Test     = { (kubectl get hpa).length -gt 1 }
  Set      = { kubectl autoscale deployment $Name --min=2 --max=5 --cpu-percent=80 }
}
