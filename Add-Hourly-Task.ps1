Write-Host ""
Write-Host "::: Add-Hourly-Task v1 :::" -ForegroundColor Cyan
Write-Host ""

# Add-Hourly-Task.ps1

# Generate a random time within the next 60 minutes
$currentTime = Get-Date
$randomOffsetMinutes = Get-Random -Minimum 0 -Maximum 60
$startTime = $currentTime.AddMinutes($randomOffsetMinutes).ToString("HH:mm")

# Define task parameters
$taskName = "Hourly"
$taskDescription = "Runs hourly maintenance tasks"
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
$arguments = '-NoLogo -NonInteractive -WindowStyle Hidden -File "%DevFolder%\Maintenance\hourly.ps1"'

# Check if task already exists and delete it if so
if ( Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue ) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Existing task '$taskName' found and deleted." -ForegroundColor Yellow
} # END if ( Get-ScheduledTask... )

# Create action
$action = New-ScheduledTaskAction -Execute $pwshPath -Argument $arguments

# Create trigger with hourly repetition for 24 hours
$trigger = New-ScheduledTaskTrigger -Once -At $startTime -RepetitionInterval ( New-TimeSpan -Hours 1 ) -RepetitionDuration ( New-TimeSpan -Hours 24 )

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ( New-TimeSpan -Hours 1 ) `
    -Hidden

# Create principal
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Register the task to run only when user is logged on, hidden
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description $taskDescription `
    -TaskPath "\"
