# ----------------------------------------------"
#  Backup-DataDrive.ps1"
#  Backs up /home/dchase/data/ to /home/dchase/data.backup/
# ----------------------------------------------"

Write-Host ""
Write-Host "::: Backup-DataDrive :::" -ForegroundColor Cyan
Write-Host ""

sync -avh --progress --inplace --partial --delete `
    /home/dchase/data/ `
    /home/dchase/data.backup/