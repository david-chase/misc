param (
    [Alias("n")]
    [string]$namespace
)

Write-Host ""
Write-Host ::: Restart-Namespace v1 ::: -ForegroundColor Cyan
Write-Host ""

# Prompt for namespace if not provided
if ( -not $namespace ) {
    $namespace = Read-Host "Enter the Kubernetes namespace"
}

# Confirm the namespace exists
$nsExists = kubectl get namespace $namespace --ignore-not-found
if ( -not $nsExists ) {
    Write-Host "Error: Namespace '$namespace' does not exist." -ForegroundColor Red
    exit 1
} # END if ( -not $nsExists )

Write-Host "Restarting Deployments and StatefulSets in namespace '$namespace'..."

# Restart all Deployments
$deployments = kubectl get deployments -n $namespace --no-headers -o custom-columns=":metadata.name"
foreach ( $deployment in $deployments ) {
    Write-Host "Restarting Deployment: $deployment"
    kubectl rollout restart deployment $deployment -n $namespace
} # END foreach ( $deployment in $deployments )

# Restart all StatefulSets
$statefulsets = kubectl get statefulsets -n $namespace --no-headers -o custom-columns=":metadata.name"
foreach ( $statefulset in $statefulsets ) {
    Write-Host "Restarting StatefulSet: $statefulset"
    kubectl rollout restart statefulset $statefulset -n $namespace
} # END foreach ( $statefulset in $statefulsets )

Write-Host "All restarts triggered successfully in namespace '$namespace'."
