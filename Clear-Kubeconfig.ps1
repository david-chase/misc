Write-Host
Write-Host ::: Clear-Kubeconfig v1 ::: -ForegroundColor Cyan
Write-Host

Write-Host Removing all clusters -ForegroundColor Green
kubectl config unset clusters
Write-Host Removing all contexts -ForegroundColor Green
kubectl config unset contexts
Write-Host Removing all users -ForegroundColor Green

kubectl config unset users
