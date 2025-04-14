
Write-Host ""
Write-Host "::: Set-HourlyCronJob.ps1 :::" -ForegroundColor Cyan
Write-Host ""

# Define the path to the target PowerShell script
$scriptPath = "$HOME/dev/Maintenance/hourly-linux.ps1"

# Define the cron job entry with logging
$cronJob = "0 * * * * pwsh -File $scriptPath >> $HOME/hourly.log 2>&1"

# Create a command to append the cron job directly
$appendCommand = "(crontab -l 2>/dev/null; echo '$cronJob') | crontab -"

try {
    bash -c $appendCommand
    if ( $LASTEXITCODE -eq 0 ) {
        Write-Host "Cron job added successfully."
    } else {
        Write-Error "Failed to add cron job via direct append."
    }
} catch {
    Write-Error "An error occurred while attempting to append the cron job. $_"
}

Write-Host ""
