# ----------------------------------------------"
#  Git-Pull.ps1"
#  Does a Git pull"
# ----------------------------------------------"

Param
(
    [string]$folder = "",
    [string]$m = ""
)

Write-Host ""
Write-Host "::: Git-Pull :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

$sGitCommand = $env:ProgramFiles + "\Git\bin\git.exe"
# Validate everything we need exists
if( -not ( Test-Path -Path $sGitCommand ) ) { Write-Host "ERROR: Could not find $sGitCommand" -ForegroundColor Red; Exit }
if( -not ( Test-Path -Path $folder ) ) { Write-Host "ERROR: Could not find target folder" -ForegroundColor Red; Exit }

if( $m -eq "" ) {
    $m = ( Get-Date -Format "yyyy.MM.dd;HH:mm;" ) + "Automated sync"
} # END if( $m -eq "" )

Push-Location $folder

Add-Log -Tags "#dev#git" -Text ( "Git pull folder " + $folder )
Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList "pull origin master"

Pop-Location