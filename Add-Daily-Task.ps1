Write-Host ""
Write-Host "::: Add-Daily-Task v1 :::" -ForegroundColor Cyan
Write-Host ""

# Add-Daily-Task.ps1

# Generate a random time between 2:00 AM and 4:59 AM
$randomHour = Get-Random -Minimum 2 -Maximum 5
$randomMinute = Get-Random -Minimum 0 -Maximum 60
$startTime = "{0:D2}:{1:D2}" -f $randomHour, $randomMinute

# Define task parameters
$taskName = "Daily"
$taskDescription = "Runs daily maintenance tasks"
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
$arguments = '-NoLogo -NonInteractive -WindowStyle Hidden -File "%DevFolder%\Maintenance\daily.ps1"'

# Check if task already exists and delete it if so
if ( Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue ) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Existing task '$taskName' found and deleted." -ForegroundColor Yellow
} # END if ( Get-ScheduledTask... )

# Create action
$action = New-ScheduledTaskAction -Execute $pwshPath -Argument $arguments

# Create trigger
$trigger = New-ScheduledTaskTrigger -Daily -At $startTime

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
