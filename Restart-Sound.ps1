Write-Host ""
Write-Host "::: Restart-Sound :::" -ForegroundColor Cyan
Write-Host ""
Write-Host "systemctl --user restart pipewire pipewire-pulse wireplumber" -ForegroundColor DarkGreen
Write-Host ""
systemctl --user restart pipewire pipewire-pulse wireplumber