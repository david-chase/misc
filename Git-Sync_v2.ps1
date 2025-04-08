param (
    [string]$RepoPath = (Get-Location),
    [switch]$All
)

Write-Host ""
<<<<<<< HEAD
Write-Host " ::: Git Sync v2 :::" -ForegroundColor Cyan
=======
Write-Host "::: Git Sync v2 :::" -ForegroundColor Cyan
>>>>>>> 82340120c6e1130cb66ba05168bd87f206e96d3e
Write-Host ""

# Remember original directory
$startPath = Get-Location

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

# Ensure Git is available
if ( -not (Get-Command git -ErrorAction SilentlyContinue) ) {
    Add-Log -Tags "#git#sync" -Text "Git not available in PATH"
    Write-Error "Git is not installed or not available in the system PATH"
    Set-Location -Path $startPath
    exit 1
} # END if ( -not (Get-Command ...) )

function Sync-GitRepo {
    param ( [string]$Path )

    Write-Host "Syncing repo at $Path"
    Add-Log -Tags "#git#sync" -Text "Starting sync for $Path"

    if ( -not (Test-Path $Path) ) {
        Write-Host "The specified path $Path does not exist" -ForegroundColor Yellow
        Add-Log -Tags "#git#sync" -Text "The specified path $Path does not exist Exiting"
                return
    } # END if ( -not (Test-Path $Path) )

    Set-Location -Path $Path

    if ( -not (Test-Path -Path (Join-Path $Path ".git")) ) {
        Write-Host "Skipping $Path Not a Git repository" -ForegroundColor Yellow
        Add-Log -Tags "#git#sync" -Text "Skipping $Path Not a Git repository"
        $global:SkippedRepos += $Path
        return
    } # END if ( .git folder not found )

    # Try git status and capture output
    $statusOutput = git status 2>&1
    if ( $statusOutput -match "detected dubious ownership" ) {
        Write-Host "Adding $Path as a safe Git directory"
        Add-Log -Tags "#git#sync" -Text "Marking $Path as a safe Git directory"
        git config --global --add safe.directory "$Path"

        # Re-run git status to confirm it now works
        $statusOutput = git status 2>&1
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Error "Git status failed after safe.directory fix"
            $global:SkippedRepos += $Path
            return
        }
    } elseif ( $LASTEXITCODE -ne 0 ) {
        Add-Log -Tags "#git#sync" -Text "Git status failed at $Path $statusOutput"
        Write-Error "Git status failed: $statusOutput"
        $global:SkippedRepos += $Path
        return
    }

    git fetch
    Add-Log -Tags "#git#sync" -Text "Fetched remote changes for $Path"

    $currentBranch = git rev-parse --abbrev-ref HEAD

    $localCommit = git rev-parse $currentBranch
    $remoteCommit = git rev-parse origin/$currentBranch

    if ( $localCommit -ne $remoteCommit ) {
        Write-Host "Pulling latest changes from remote"
        Add-Log -Tags "#git#sync" -Text "Pulling changes for $Path"
        git pull origin $currentBranch
    } else {
        Write-Host "No changes to pull"
        Add-Log -Tags "#git#sync" -Text "No remote changes to pull for $Path"
    } # END if ( $localCommit -ne $remoteCommit )

    # Check if remote is under allowed GitHub accounts
    $remoteUrl = git config --get remote.origin.url
    if ( $remoteUrl -match "github\.com/(david-chase|dbc13543)/" ) {
        # Check for uncommitted changes
        $status = git status --porcelain
        if ($status) {
            Write-Host "Uncommitted changes detected committing changes"
            git add -A
            git commit -m "Automated commit by Git Sync Script"
        }

        Write-Host "Pushing local changes to remote"
        Add-Log -Tags "#git#sync" -Text "Pushing changes for $Path"
        git push origin $currentBranch
    } else {
        Write-Host "Skipping push for $Path because remote is not an allowed GitHub account" -ForegroundColor Yellow
    }

    Write-Host "Sync completed for $Path"
    Add-Log -Tags "#git#sync" -Text "Sync completed for $Path"
} # END function Sync-GitRepo

if ( $All ) {
    Add-Log -Tags "#git#sync" -Text "Syncing all directories in $(Get-Location)"
    $basePath = Get-Location
    $folders = Get-ChildItem -Path $basePath -Directory
    foreach ( $folder in $folders ) {
        Sync-GitRepo -Path $folder.FullName
    } # END foreach
} else {
    Sync-GitRepo -Path $RepoPath
} # END if ( $All )

# Return to the original directory before exiting
Set-Location -Path $startPath
