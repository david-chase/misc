param (
    [Parameter( Mandatory = $true )]
    [string] $n
)

Clear-Host

Write-Host ""
Write-Host "::: Watch-Pod-Resources.ps1 :::" -ForegroundColor Cyan
Write-Host ""

while ( $true ) {

    [Console]::SetCursorPosition( 0, 0 )

    Write-Host ""
    Write-Host "::: Watch-Pod-Resources.ps1 :::" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Namespace: $n   (refreshed every 5 seconds)   $(Get-Date -Format HH:mm:ss)" -ForegroundColor Yellow
    Write-Host ""

    $pods = kubectl get pods -n $n -o json | ConvertFrom-Json

    $output = foreach ( $pod in $pods.items ) {

        foreach ( $container in $pod.spec.containers ) {

            $status = $pod.status.containerStatuses |
                Where-Object { $_.name -eq $container.name }

            [PSCustomObject] @{
                Pod         = $pod.metadata.name
                Container   = $container.name
                CPU_Request = $container.resources.requests.cpu
                CPU_Limit   = $container.resources.limits.cpu
                Mem_Request = $container.resources.requests.memory
                Mem_Limit   = $container.resources.limits.memory
                Restarts    = if ( $status ) { $status.restartCount } else { 0 }
            }

        } # END foreach ( $container )

    } # END foreach ( $pod )

    $output |
        Sort-Object Pod, Container |
        Format-Table -AutoSize

    Start-Sleep -Seconds 5

} # END while ( $true )
