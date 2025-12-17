param ( )

Write-Host ""
Write-Host "::: Pause-Kubex-Automation.ps1 :::" -ForegroundColor Cyan
Write-Host ""

$annotationKey   = "rightsizing.kubex.ai/pause-until"
$annotationValue = "infinite"

$namespaces = kubectl get ns -o json |
    ConvertFrom-Json |
    Select-Object -ExpandProperty items |
    Where-Object { $_.metadata.name -like "retailstore-*" } |
    Select-Object -ExpandProperty metadata |
    Select-Object -ExpandProperty name

foreach ( $ns in $namespaces ) {

    Write-Host "Pausing Kubex automation in namespace: $ns" -ForegroundColor Yellow

    kubectl annotate deployment -n $ns --all `
        "$annotationKey=$annotationValue" `
        --overwrite

    kubectl annotate statefulset -n $ns --all `
        "$annotationKey=$annotationValue" `
        --overwrite

} # END foreach ( $ns )

Write-Host ""
Write-Host "Kubex automation paused in all retailstore namespaces." -ForegroundColor Green
Write-Host ""
