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
# Set maximum number of Timeshift snapshots to keep
$iBackupsToKeep = 5

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

# Purge Old Timeshift Snapshots
Write-Host "`nPurging old Timeshift snapshots (Keeping most recent: $iBackupsToKeep)..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#cleanup" -Text ( "Purging old Timeshift snapshots to keep only the top $iBackupsToKeep" )

# 1. Get the list of snapshots from Timeshift.
# Timeshift list output contains tags, device info, and timestamps in 'yyyy-MM-dd_HH-mm-ss' format.
$sSnapshotList = sudo timeshift --list

# 2. Extract lines containing valid timestamps using a regex pattern matching the Timeshift naming convention
$sSnapshots = $sSnapshotList | Where-Object { $_ -match '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}' } | ForEach-Object { $Matches[0] }

# 3. Check if we actually have more snapshots than our threshold
if ($sSnapshots.Count -gt $iBackupsToKeep) {
    # Timeshift lists snapshots chronologically (oldest first). 
    # We select from index 0 up to the surplus count to isolate the oldest snapshots.
    $iSurplusCount = $sSnapshots.Count - $iBackupsToKeep
    $sSnapshotsToDelete = $sSnapshots | Select-Object -First $iSurplusCount

    Write-Host "Found $($sSnapshots.Count) snapshots. Removing $iSurplusCount oldest backup(s)..." -ForegroundColor Gray

    foreach ($sSnapshotTag in $sSnapshotsToDelete) {
        Write-Host "Deleting snapshot: $sSnapshotTag..." -ForegroundColor DarkGray
        # Execute the native deletion command via sudo
        sudo timeshift --delete --snapshot "$sSnapshotTag" | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Add-Log -Tags "#maintenance#cleanup" -Text ( "Successfully deleted Timeshift snapshot: $sSnapshotTag" )
        } else {
            Write-Warning "Failed to delete snapshot: $sSnapshotTag"
        }
    }
    Write-Host "✓ Snapshot purge complete." -ForegroundColor Green
} else {
    Write-Host "✓ Snapshot count ($($sSnapshots.Count)) is within the allowed limit of $iBackupsToKeep. No deletion required." -ForegroundColor Green
}

# Update firmware
Write-Host "`nUpdating firmwares..." -ForegroundColor Yellow
Add-Log -Tags "#maintenance#cleanup" -Text ( "Updating firmwares" )

sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update

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
