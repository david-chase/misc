
param (
    [string] $RepoPath = (Get-Location)
)

Write-Host ""
Write-Host "::: Git-Sync.ps1 :::" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking Git repository at: $RepoPath"
Write-Host ""

# Validate the folder exists
if ( -Not (Test-Path -Path $RepoPath -PathType Container) ) {
    Write-Error "The specified folder does not exist: $RepoPath"
    exit 1
}

# Check if it's a Git repo
$gitDir = Join-Path -Path $RepoPath -ChildPath ".git"
if ( -Not (Test-Path -Path $gitDir -PathType Container) ) {
    Write-Error "The specified folder is not a Git repository: $RepoPath"
    exit 1
}

# Move to repo directory
Set-Location -Path $RepoPath

# Pull from remote
Write-Host "Pulling from remote..."
git pull origin main --no-rebase

# Stage all changes
Write-Host "Staging changes..."
git add -A

# Commit if there are changes to commit
$hasChanges = git status --porcelain
if ( $hasChanges ) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    git commit -m "Auto-sync commit on $timestamp"
    Write-Host "Committed local changes."
} else {
    Write-Host "No changes to commit."
}

# Push to remote
Write-Host "Pushing to remote..."
git push --all

Write-Host ""
Write-Host "Sync complete for '$RepoPath'" -ForegroundColor Green
