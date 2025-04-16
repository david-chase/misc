
Write-Host ""
Write-Host "::: Git-Init.ps1 :::" -ForegroundColor Cyan
Write-Host ""

# Get the current folder name to use in the Git remote URL
$currentFolder = Split-Path -Leaf (Get-Location)

# Step 1: Initialize Git repository with 'main' as the default branch
git init -b main

# Step 2: Add remote origin using folder name in the GitHub URL
git remote add origin "git@github.com:david-chase/$currentFolder.git"

# Step 3: Pull from remote main using merge strategy, allow unrelated histories
git pull origin main --no-rebase --allow-unrelated-histories

# Step 4: Add all files to staging
git add *

# Step 5: Commit the changes
git commit -m "Initial commit"

# Step 6: Push to remote and set upstream
git push --set-upstream origin main
