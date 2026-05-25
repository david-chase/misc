Write-Host 
Write-Host ::: Update-Ubuntu ::: -ForegroundColor Cyan
Write-Host 

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

# Locate the log file so I can truncate it
$sLogFile = $sDevFolder + [IO.Path]::DirectorySeparatorChar + "Logs" + [IO.Path]::DirectorySeparatorChar + "AllEvents.log"

# Set maximum allowed lines for the text log
$iLogFileLength = 2000

Add-Log -Tags "#maintenance#upgrade" -Text ( "Starting Ubuntu regular upgrade process" )

# Take a Timeshift Snapshot
Write-Host "Creating Timeshift Snapshot..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Taking a Timeshift snapshot" )

# Running via sudo. If sudo needs a password, it will prompt here.
sudo timeshift --create --comments "Automated PowerShell Maintenance Backup"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Timeshift snapshot failed or was skipped. Proceeding with caution..."
} else {
    Write-Host "✓ Snapshot created successfully." -ForegroundColor Green
}

# Update and Upgrade APT Packages
Write-Host "`nUpdating and Upgrading APT Packages..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Upgrading apt packages" )

sudo apt-get update
sudo apt-get dist-upgrade -y
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ APT packages upgraded successfully." -ForegroundColor Green
}

# Upgrade Snap Packages
Write-Host "`nUpgrading Snap Packages..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Upgrading snap packages" )

sudo snap refresh
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Snap packages refreshed successfully." -ForegroundColor Green
}

# Clean up Residual and Orphaned Packages
Write-Host "`nCleaning up unused dependencies and package cache..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Cleaning up unused dependencies and package cache" )

sudo apt-get autoremove -y
sudo apt-get autoclean -y
Write-Host "✓ APT cache and dependencies cleaned." -ForegroundColor Green

# Rotate and Vacuum Systemd Journal Logs
Write-Host "`nVacuuming systemd journal logs to free up space..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#upgrade" -Text ( "Vacuuming systemd journal logs to free up space" )

sudo journalctl --vacuum-time=14d
Write-Host "✓ Journal logs optimized." -ForegroundColor Green

# Truncate Log File
Write-Host "`nTruncating event log to the most recent $iLogFileLength entries..." -ForegroundColor Yellow

if (Test-Path $sLogFile) {
    # Read the file, grab only the last X lines, and force-write it back
    # Using parentheses around Get-Content ensures the file is read entirely 
    # into memory and closed, avoiding "file in use" lock errors.
    (Get-Content -Path $sLogFile | Select-Object -Last $iLogFileLength) | Set-Content -Path $sLogFile
    
    Add-Log -Tags "#maintenance#cleanup" -Text ( "Log file truncated to the most recent $iLogFileLength lines." )
    Write-Host "✓ Log file optimized and truncated." -ForegroundColor Green
} else {
    Write-Warning "Log file not found at $sLogFile. Skipping truncation."
}

# Check if a Reboot is Required
Write-Host "`nChecking if a system reboot is required..." -ForegroundColor Yellow
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
