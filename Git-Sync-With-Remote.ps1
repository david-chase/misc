# Git-Sync-With-Remote.ps1
# 1. Backup local changes (Stash)
# 2. Align local branch with remote origin/main
# 3. Re-apply local changes
# 4. Commit and Push back to remote

Write-Host "Starting Git sync process..." -ForegroundColor Cyan

# Check for local changes and stash them
$hasChanges = (git status --porcelain)
if ($hasChanges) {
    Write-Host "Local changes detected. Backing up to stash..." -ForegroundColor Yellow
    git stash push -m "Backup before sync $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
} else {
    Write-Host "No local changes to backup." -ForegroundColor Gray
}

# Fetch latest from remote
Write-Host "Fetching from remote..." -ForegroundColor Cyan
git fetch origin

# Reset local branch to match remote 'main' (Adjust to 'master' if needed)
# Using 'main' as it is the current industry standard, change to 'master' if your repo uses it.
Write-Host "Setting local branch to match remote..." -ForegroundColor Cyan
git reset --hard origin/main

# Re-apply the stashed changes
if ($hasChanges) {
    Write-Host "Re-applying local changes (Copying diffs over top)..." -ForegroundColor Yellow
    git stash pop
    
    # Add, commit, and push the merged changes
    Write-Host "Pushing local diffs to remote..." -ForegroundColor Cyan
    git add .
    git commit -m "Synced local diffs with remote"
    git push origin main
}

Write-Host "Sync complete!" -ForegroundColor Green