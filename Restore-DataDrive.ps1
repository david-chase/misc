# ----------------------------------------------"
#  Restore-DataDrive.ps1"
#  Backs up /home/dchase/data.backup/ to /home/dchase/data/
# ----------------------------------------------"

Write-Host ""
Write-Host "::: Restore-DataDrive :::" -ForegroundColor Cyan
Write-Host ""

Write-Host ""
Write-Host "WARNING: This operation will DESTROY existing data in /home/dchase/data/" -ForegroundColor Red
Write-Host "This action is IRREVERSIBLE." -ForegroundColor Red
Write-Host ""
Write-Host "To proceed, type YES (all caps). Any other input will cancel." -ForegroundColor Red
Write-Host ""

$Confirmation = Read-Host "CONFIRMATION"

if ( $Confirmation -ne "YES" ) {
    Write-Host ""
    Write-Host "Operation cancelled. No data was changed." -ForegroundColor Yellow
    Write-Host ""
    exit 1
} # END if ( $Confirmation -ne "YES" )

Write-Host ""
Write-Host "Confirmation accepted. Proceeding with data restore..." -ForegroundColor Green
Write-Host ""

rsync -avh --progress --inplace --partial --delete `
    /home/dchase/data.backup/ `
    /home/dchase/data/
