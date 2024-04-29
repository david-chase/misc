Write-Host 
Write-Host ::: Backup Data ::: -ForegroundColor Cyan
Write-Host 

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

Add-Log -Tags "#backup#edo" -Text "Backing up EDO (X:) to EDO (Y:)..."
. robocopy x:\ y:\ /e /w:1 /r:1 /purge /np /xd $RECYCLE.BIN "System Volume Information" | Tee-Object -Filepath "$env:DevFolder\Logs\Backup-Data.log" -Append

Add-Log -Tags "#backup" -Text "Completed EDO backup"