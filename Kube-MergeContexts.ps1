# ----------------------------------------------"
#  Kube-MergeContexts.ps1"
#  Merges any contexts in ~/kube into a single file named "config"
# ----------------------------------------------"

Write-Host ""
Write-Host "::: Kube-MergeContexts :::" -ForegroundColor Cyan
Write-Host ""

# Merge all kubeconfig files in ~/.kube into ~/.kube/config

$kubeDir  = "$HOME/.kube"
$files    = Get-ChildItem $kubeDir -File | Where-Object { $_.Name -ne "config" }
$separator = if ( $IsWindows ) { ';' } else { ':' }

$env:KUBECONFIG = ( $files.FullName ) -join $separator

kubectl config view --merge --flatten | Set-Content "$kubeDir/config"