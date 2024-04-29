#-------------------------------------------------------------------
#  Set-SoundDevice v1
#  Sets the current audio device
#  Requires AudioDeviceCmdLets 3.1.0.2 from PowerShell Gallery
#-------------------------------------------------------------------

Param
(
    [string]$sShortName = "speakers"
) 

Write-Host ""
Write-Host ::: Set-SoundDevice ::: -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
if( -not ( Test-Path -Path $sSharedFunctions ) ) { Write-Host ERROR: Could not access $sSharedFunctions -ForegroundColor Red; Exit }
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

$sShortName = $sShortName.ToLower()
$aDeviceNames = Import-CSV -Path ( $sDataFiles + "\Set-SoundDevice.csv" ) 
$aAudioDevices = Get-AudioDevice -List | Where-Object Type -eq "Playback"

$aDeviceName = $aDeviceNames | Where-Object nickname -eq $sShortName
if( $aDeviceName.Count -lt 1 ) { Write-Host "ERROR: Can't find the short name $sShortName" -ForegroundColor Red; Exit }
if( $aDeviceName.Count -gt 1 ) { Write-Host "ERROR: Multiple short names called $sShortName" -ForegroundColor Red; Exit }

# So this is a valid short name, but we need to see if it matches exactly one audio device
$oDesiredAudioDevice = $aAudioDevices | Where-Object Name -eq $aDeviceName[ 0 ].matchstring
if( $oDesiredAudioDevice.Count -lt 1 ) { Write-Host "ERROR: No audio device matches the short name $sShortName" -ForegroundColor Red; Exit }
if( $oDesiredAudioDevice.Count -gt 1 ) { Write-Host "ERROR: Multiple audio devices are a match for $sShortName" -ForegroundColor Red; Exit }

# The short name is valid, and it matches exactly one audio device.  So set it.
$sOutString = "Setting Audio Device to " + $sShortName.ToUpper()
Write-Host $sOutString
Set-AudioDevice -Index $oDesiredAudioDevice.Index | Out-Null
[console]::beep(250,500)