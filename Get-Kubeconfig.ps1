Write-Host
Write-Host ::: Get-Kubeconfig v1 ::: -ForegroundColor Cyan
Write-Host

# Get kubeconfig content
$kubeconfig = kubectl config view --raw -o json | ConvertFrom-Json

# Output Contexts
Write-Host "`nContexts" -ForegroundColor Cyan

foreach ($context in $kubeconfig.contexts) {
    Write-Host "- $($context.name)"
}

# Output Clusters
Write-Host "`nClusters" -ForegroundColor Cyan
foreach ($cluster in $kubeconfig.clusters) {
    Write-Host "- $($cluster.name)"
}

# Output Users
Write-Host "`nUsers" -ForegroundColor Cyan
foreach ($user in $kubeconfig.users) {
    Write-Host "- $($user.name)"
}