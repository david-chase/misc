$sSource = "G:\models.vid\"
$sBackup = "H:\models.vid\"
$iTotalFiles = 0
$iTotalMatches = 0

cd $sSource
$aFiles = @(Get-ChildItem "*.mp4" -File )

foreach( $oFile in $aFiles ) {
    $iTotalFiles++
    $sBackupFile = $oFile.Name.Replace( "#5", "#?" )
    $sBackupFile = $sBackupFile.Replace( "#4", "#?" )
    $sBackupFile = $sBackupFile.Replace( "#3", "#?" )
    $sBackupFile = $sBackupFile.Replace( "#2", "#?" )
    $sBackupFile = $sBackupFile.Replace( "#1", "#?" )
    $sBackupFile = $sBackup + $sBackupFile
    $aBackups = @(Get-ChildItem $sBackupFile -File )
    if( ( $aBackups.Count -gt 0 ) -and ( $aBackups[ 0 ].Name -ne $oFile.Name ) ) {
        $iTotalMatches++
        Rename-Item -Path $oFile.Name -NewName $aBackups[ 0 ].Name
    } 
}

Write-Host Total Files $iTotalFiles
Write-Host Total Matches $iTotalMatches