param (
    [Alias("n")]
    [string]$namespace,

    [Alias("l")]
    [string]$label
)

Write-Host ""
Write-Host ::: Enable-Densify-Automation v1 ::: -ForegroundColor Cyan
Write-Host ""

if ( -not $namespace ) {
    $namespace = Read-Host "Enter the namespace to apply the label to"
}

if ( -not $label ) {
    $label = Read-Host "Enter the label to apply [default: densify-automation=true]"
    if ( -not $label ) {
        $label = "densify-automation=true"
    }
}

# Check if namespace exists
$nsExists = kubectl get namespace $namespace -o name 2>$null
if ( -not $nsExists ) {
    Write-Host "Error: Namespace '$namespace' does not exist." -ForegroundColor Red
    exit 1
}

$resources = @("pods", "deployments", "statefulsets", "daemonsets")

foreach ( $resource in $resources ) {
    kubectl get $resource -n $namespace -o name | ForEach-Object {
        kubectl label -n $namespace $_ $label --overwrite
    }
}
