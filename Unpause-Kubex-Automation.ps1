param ( )

Write-Host ""
Write-Host "::: Unpause-Kubex-Automation.ps1 :::" -ForegroundColor Cyan
Write-Host ""

$annotationKey = "rightsizing.kubex.ai/pause-until"

$namespaces = kubectl get ns -o json |
    ConvertFrom-Json |
    Select-Object -ExpandProperty items |
    Where-Object { $_.metadata.name -like "retailstore-*" } |
    Select-Object -ExpandProperty metadata |
    Select-Object -ExpandProperty name

foreach ( $ns in $namespaces ) {

    Write-Host "Unpausing Kubex automation in namespace: $ns" -ForegroundColor Yellow

    kubectl annotate deployment -n $ns --all `
        "$annotationKey-" `
        --overwrite

    kubectl annotate statefulset -n $ns --all `
        "$annotationKey-" `
        --overwrite

} # END foreach ( $ns )

Write-Host ""
Write-Host "Kubex automation unpaused in all retailstore namespaces." -ForegroundColor Green
Write-Host ""
