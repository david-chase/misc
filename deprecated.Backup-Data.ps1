Write-Host 
Write-Host ::: Backup Data ::: -ForegroundColor Cyan
Write-Host 

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

Add-Log -Tags "#backup#data#media" -Text "Backing up ALLDATA (C:) to MEDIA.BAK (I:)..."
. robocopy C:\AllData i:\ /e /w:1 /r:1 /purge /np /xd $RECYCLE.BIN "System Volume Information" | Tee-Object -Filepath "$env:DevFolder\Logs\Backup-Data.log" -Append

Add-Log -Tags "#backup#collection" -Text "Backing up COLLECTION (G:) to COLLECTION.BAK (H:)..."
robocopy g:\ h:\ /e /w:1 /r:1 /purge /np /xd $RECYCLE.BIN "System Volume Information" | Tee-Object -Filepath "$env:DevFolder\Logs\Backup-Data.log" -Append

Add-Log -Tags "#backup" -Text "Completed full system backup"