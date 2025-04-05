# ----------------------------------------------"
#  Git-SyncFrom-Remote.ps1"
#  Resets my local repo to be in sync with the remote
# ----------------------------------------------"

Param
(
    [string]$folder = ""
)

Write-Host ""
Write-Host "::: Git-SyncFrom-Remote :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

$sGitCommand = "git"
# Validate everything we need exists
if( -not ( Test-Path -Path $folder ) ) { Write-Host "ERROR: Could not find target folder" -ForegroundColor Red; Exit }

Push-Location $folder

Add-Log -Tags "#dev#git" -Text ( "Git forcing sync from remote for " + $folder )
Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList "fetch origin"
Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList "reset --hard origin/master"

Pop-Location