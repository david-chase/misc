param (
    [string]$RepoPath = (Get-Location),
    [switch]$All
)

Write-Host ""
Write-Host "::: Git-Sync v2 :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

# Ensure Git is available
if ( -not (Get-Command git -ErrorAction SilentlyContinue) ) {
    Add-Log -Tags "#git#sync" -Text "Git not available in PATH."
    Write-Error "Git is not installed or not available in the system PATH."
    exit 1
} # END if ( -not (Get-Command ...) )

function Sync-GitRepo {
    param ( [string]$Path )

    Write-Host "\n--- Syncing repo at: $Path ---" -ForegroundColor Yellow
    Add-Log -Tags "#git#sync" -Text "Starting sync for: $Path"

    Set-Location -Path $Path

    $gitDirTest = git rev-parse --is-inside-work-tree 2>$null
    if ( $LASTEXITCODE -ne 0 -or $gitDirTest -ne "true" ) {
        Add-Log -Tags "#git#sync" -Text "Skipping '$Path': Not a Git repository."
        Write-Warning "Skipping '$Path': Not a Git repository."
        return
    } # END if ( not a git repo )

    try {
        git status > $null 2>&1
    } catch {
        if ( $_.Exception.Message -match "detected dubious ownership" ) {
            Write-Host "Adding $Path as a safe Git directory..."
            Add-Log -Tags "#git#sync" -Text "Marking '$Path' as a safe Git directory."
            git config --global --add safe.directory "$Path"
        } else {
            Add-Log -Tags "#git#sync" -Text "Git status failed at '$Path': $($_.Exception.Message)"
            Write-Error "Git status failed: $($_.Exception.Message)"
            return
        } # END if ( match )
    } # END try-catch

    git fetch
    Add-Log -Tags "#git#sync" -Text "Fetched remote changes for '$Path'"

    $currentBranch = git rev-parse --abbrev-ref HEAD
    $remoteBranch = git rev-parse --abbrev-ref "origin/$currentBranch"

    if ( $currentBranch -ne $remoteBranch ) {
        Add-Log -Tags "#git#sync" -Text "Branch mismatch in '$Path': local='$currentBranch', remote='$remoteBranch'"
        Write-Error "Local branch '$currentBranch' does not match remote branch '$remoteBranch'."
        return
    } # END if ( $currentBranch -ne $remoteBranch )

    $localCommit = git rev-parse $currentBranch
    $remoteCommit = git rev-parse origin/$currentBranch

    if ( $localCommit -ne $remoteCommit ) {
        Write-Host "Pulling latest changes from remote..."
        Add-Log -Tags "#git#sync" -Text "Pulling changes for '$Path'"
        git pull origin $currentBranch
    } else {
        Write-Host "No changes to pull."
        Add-Log -Tags "#git#sync" -Text "No remote changes to pull for '$Path'"
    } # END if ( $localCommit -ne $remoteCommit )

    Write-Host "Pushing local changes to remote..."
    Add-Log -Tags "#git#sync" -Text "Pushing changes for '$Path'"
    git push origin $currentBranch

    Write-Host "Sync completed for $Path."
    Add-Log -Tags "#git#sync" -Text "Sync completed for '$Path'"
} # END function Sync-GitRepo

if ( $All ) {
    Add-Log -Tags "#git#sync" -Text "Syncing all directories in: $(Get-Location)"
    $basePath = Get-Location
    $folders = Get-ChildItem -Path $basePath -Directory
    foreach ( $folder in $folders ) {
        Sync-GitRepo -Path $folder.FullName
    } # END foreach
} else {
    Sync-GitRepo -Path $RepoPath
} # END if ( $All )
