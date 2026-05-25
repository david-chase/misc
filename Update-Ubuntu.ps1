Write-Host 
Write-Host ::: Update-Ubuntu ::: -ForegroundColor Cyan
Write-Host 

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

Add-Log -Tags "#maintenance#upgrade" -Text ( "Starting Ubuntu regular upgrade process" )

# 1. Take a Timeshift Snapshot
Write-Host "[1/6] Creating Timeshift Snapshot..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Taking a Timeshift snapshot" )

# Running via sudo. If sudo needs a password, it will prompt here.
sudo timeshift --create --comments "Automated PowerShell Maintenance Backup"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Timeshift snapshot failed or was skipped. Proceeding with caution..."
} else {
    Write-Host "✓ Snapshot created successfully." -ForegroundColor Green
}

# 2. Update and Upgrade APT Packages
Write-Host "`n[2/6] Updating and Upgrading APT Packages..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Upgrading apt packages" )

sudo apt-get update
sudo apt-get dist-upgrade -y
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ APT packages upgraded successfully." -ForegroundColor Green
}

# 3. Upgrade Snap Packages
Write-Host "`n[3/6] Upgrading Snap Packages..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Upgrading snap packages" )

sudo snap refresh
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Snap packages refreshed successfully." -ForegroundColor Green
}

# 4. Clean up Residual and Orphaned Packages
Write-Host "`n[4/6] Cleaning up unused dependencies and package cache..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Cleaning up unused dependencies and package cache" )

sudo apt-get autoremove -y
sudo apt-get autoclean -y
Write-Host "✓ APT cache and dependencies cleaned." -ForegroundColor Green

# 5. Rotate and Vacuum Systemd Journal Logs
Write-Host "`n[5/6] Vacuuming systemd journal logs to free up space..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Vacuuming systemd journal logs to free up space" )

sudo journalctl --vacuum-time=14d
Write-Host "✓ Journal logs optimized." -ForegroundColor Green

# 6. Check if a Reboot is Required
Write-Host "`n[6/6] Checking if a system reboot is required..." -ForegroundColor Yellow
if (Test-Path "/var/run/reboot-required") {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host " ATTENTION: A system reboot is required to apply " -ForegroundColor Red
    Write-Host " kernel or critical library updates.                " -ForegroundColor Red
    Write-Host "====================================================" -ForegroundColor Red
} else {
    Write-Host "✓ No reboot required at this time." -ForegroundColor Green
}

Write-Host "`n=== Maintenance Task Complete ===" -ForegroundColor Cyan
