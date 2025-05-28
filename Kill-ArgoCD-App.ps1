
param (
    [Parameter(Mandatory = $true)]
    [string]$AppName
)

Write-Host ""
Write-Host "::: Kill-ArgoCD App :::" -ForegroundColor Cyan
Write-Host ""

# Check if the application exists
$app = kubectl get application $AppName -n argocd -o json 2>$null
if ( -not $app ) {
    Write-Host "Application '$AppName' not found in namespace 'argocd'." -ForegroundColor Red
    exit 1
}

# Parse finalizers
$finalizers = ($app | ConvertFrom-Json).metadata.finalizers
if ( -not $finalizers -or $finalizers.Count -eq 0 ) {
    Write-Host "No finalizers found on application '$AppName'. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

# Remove the finalizers
Write-Host "Removing finalizers from application '$AppName'..." -ForegroundColor Green
kubectl patch application $AppName -n argocd `
  --type=json `
  -p '[ { "op": "remove", "path": "/metadata/finalizers" } ]'

Write-Host "Finalizers removed. Deletion should now complete." -ForegroundColor Green
Write-Host ""

