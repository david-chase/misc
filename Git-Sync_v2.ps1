param (
    [string] $RepoPath = (Get-Location),
    [Alias("m")]
    [string] $Message
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
Push-Location -Path $RepoPath

try {
    # Determine current branch
    $branch = git rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not determine current branch."
        exit 1
    }
    Write-Host "Current branch: $branch"
    Write-Host ""

    # Pull from remote
    Write-Host "Pulling from remote..."
    git pull origin $branch --no-rebase
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Pull failed. Resolve conflicts manually, then re-run this script."
        exit 1
    }

    # Stage all changes
    Write-Host "Staging changes..."
    git add -A

    # Commit if there are changes to commit
    $hasChanges = git status --porcelain
    if ( $hasChanges ) {
        $commitMessage = $Message
        if ( [string]::IsNullOrWhiteSpace($commitMessage) -and [Environment]::UserInteractive ) {
            $commitMessage = Read-Host "Enter commit message (leave blank to use timestamp)"
        }
        if ( [string]::IsNullOrWhiteSpace($commitMessage) ) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $commitMessage = "Auto-sync commit on $timestamp"
        }

        git commit -m $commitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Commit failed."
            exit 1
        }
        Write-Host "Committed local changes."
    } else {
        Write-Host "No changes to commit."
    }

    # Push current branch to remote
    Write-Host "Pushing to remote..."
    git push origin $branch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Push failed."
        exit 1
    }

    Write-Host ""
    Write-Host "Sync complete for '$RepoPath' on branch '$branch'" -ForegroundColor Green
}
finally {
    # Always return to the starting folder, even on error
    Pop-Location
}