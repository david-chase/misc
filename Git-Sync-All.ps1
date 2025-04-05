# ----------------------------------------------"
#  Git-Sync-All.ps1"
#  Looks at all subfolders in the current directory
#  If they're a git repository owned by me, do a Pull then Push
#  If they're owned by someone else, just do a Pull
# ----------------------------------------------"

Write-Host ""
Write-Host "::: Git-Sync-All :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

$sGitCommand = $env:ProgramFiles + "\Git\bin\git.exe"
# Validate the Git binary exists
if( -not ( Test-Path -Path $sGitCommand ) ) { Write-Host "ERROR: Could not find $sGitCommand" -ForegroundColor Red; Exit }

# Form the commit comment
$m = ( Get-Date -Format "yyyy.MM.dd;HH:mm;" ) + "Automated sync"

$aFolders = Get-ChildItem * -Directory
ForEach( $sFolder in $aFolders) {
    Push-Location $sFolder
    $sFolderShortName = $sFolder.ToString().Replace( ( $sDevFolder + "\" ), "" )
    if( Test-Path -Path ".git" ) {

        $sAuthor = ( git for-each-ref --format='%(authorname)' )[ 1 ]
        if( $sAuthor -eq "David Chase" )  {
            # I'm the author of this repository
            Write-Host Syncing my repo $sFolderShortName -ForegroundColor Cyan

            Add-Log -Tags "#dev#git" -Text ( "Git pull folder " + $sFolderShortName )
            Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList "pull origin master"

            Add-Log -Tags "#dev#git" -Text ( "Git commit and push of folder " + $sFolderShortName ) 
            Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList "add *" 
            $sCommitString = 'commit -m "' + $m + '" '
            Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList $sCommitString
            Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList " push --all" 
        } # if( $sAuthor -eq "David Chase" )
        else {
            # I'm NOT the author of this repository
            Write-Host Pulling foreign repo $sFolderShortName -ForegroundColor Cyan

            Add-Log -Tags "#dev#git" -Text ( "Git pull folder " + $sFolderShortName )
            Start-Process $sGitCommand -NoNewWindow -Wait -ArgumentList "pull origin master"

        } # if( $sAuthor -eq "David Chase" )

    } # if( Get-ChildItem -Name ".git" -Directory -Hidden )
    else{
        Write-Host Skipping $sFolderShortName Not a git repository -ForegroundColor Cyan
        Add-Log -Tags "#dev#git" -Text ( "$sFolderShortName Not a git repository" ) 
    }

    Pop-Location
} # ForEach( $sFolder in $aFolders)