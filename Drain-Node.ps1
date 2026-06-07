param (
    [Parameter( Mandatory = $true )]
    [string] $n,
    [switch] $s
)

if (-not $s) {
    Clear-Host

    Write-Host ""
    Write-Host "::: Drain-Node.ps1 :::" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Draining node: $n" -ForegroundColor Yellow
    Write-Host ""
}

if ($s) {
    kubectl drain $n `
        --ignore-daemonsets `
        --delete-emptydir-data `
        --force *> $null
}
else {
    kubectl drain $n `
        --ignore-daemonsets `
        --delete-emptydir-data `
        --force

    Write-Host ""
    Write-Host "Drain operation completed for node: $n" -ForegroundColor Green
    Write-Host ""
}
