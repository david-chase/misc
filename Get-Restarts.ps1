param (
    [string] $n
)

Write-Host ""
Write-Host "::: Get-Restarts.ps1 :::" -ForegroundColor Cyan
Write-Host ""

if ( $n ) {

    kubectl get pods -n $n `
        -o "custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount"

} else {

    kubectl get pods -A `
        -o "custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount"

} # END if ( $n )
