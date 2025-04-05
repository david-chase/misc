Write-Host
Write-Host ::: Add-EKSCluster v1 ::: -ForegroundColor Cyan
Write-Host

$aClusters = ( aws eks list-clusters --output json | ConvertFrom-Json ).clusters
# $aClusters | Out-Host

$iCounter = 0
foreach($sCluster in $aClusters) {
    $iCounter++
    $sTempString = $iCounter.ToString() + ". " + $sCluster
    Write-Host $sTempString
}
Write-Host
$iClusterIndex = Read-Host "Enter the number of the cluster to add"
$sClusterName = $aClusters[ $iClusterIndex - 1 ]

Write-Host
Write-Host "aws eks update-kubeconfig --name $sClusterName" -ForegroundColor Green
aws eks update-kubeconfig --name $sClusterName


