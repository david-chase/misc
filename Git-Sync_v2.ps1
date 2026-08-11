param (
    [string] $RepoPath = (Get-Location),
    [switch] $All
)

Write-Host ""
Write-Host " ::: Git-Sync v3 ::: " -ForegroundColor Cyan
Write-Host ""

# Remember original directory
$sStartPath = Get-Location

# Include functions and parse environment variables
if ( [string]::IsNullOrWhiteSpace( $env:SharedFunctions ) -or -not ( Test-Path $env:SharedFunctions ) ) {
    Write-Error "`$env:SharedFunctions is not set or does not exist."
    exit 1
}
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
Pop-Location

# Ensure Git is available
if ( -not (Get-Command git -ErrorAction SilentlyContinue) ) {
    Add-Log -Tags "#git#sync" -Text "Git not available in PATH"
    Write-Error "Git is not installed or not available in the system PATH"
    Set-Location -Path $sStartPath
    exit 1
} # END if ( -not (Get-Command ...) )

# Prevent overlapping runs - repos synced by this script can live on shared
# network drives, so two people (or two machines) running this at once
# against the same path is a real risk, not just a theoretical one.
$sLockPath = Join-Path $env:Temp "Git-Sync.lock"
if ( Test-Path $sLockPath ) {
    Write-Error "A previous run appears to still be in progress (lock file present at $sLockPath). If you're sure no other run is active, delete this file and try again."
    Add-Log -Tags "#git#sync" -Text "Aborted - lock file already present"
    exit 1
}
New-Item -Path $sLockPath -ItemType File -Force | Out-Null

# Track repos that were skipped so we can summarize at the end
$global:SkippedRepos = @()

function Sync-GitRepo {
    param ( [string] $Path )

    Write-Host "Syncing repo at $Path" -ForegroundColor Green
    Add-Log -Tags "#git#sync" -Text "Starting sync for $Path"

    if ( -not (Test-Path $Path) ) {
        Write-Host "The specified path $Path does not exist" -ForegroundColor Yellow
        Add-Log -Tags "#git#sync" -Text "The specified path $Path does not exist Exiting"
        $global:SkippedRepos += $Path
        return
    } # END if ( -not (Test-Path $Path) )

    if ( -not (Test-Path -Path (Join-Path $Path ".git")) ) {
        Write-Host "Skipping $Path Not a Git repository" -ForegroundColor Yellow
        Add-Log -Tags "#git#sync" -Text "Skipping $Path Not a Git repository"
        $global:SkippedRepos += $Path
        return
    } # END if ( .git folder not found )

    Push-Location -Path $Path

    # Bail out if the repo is already mid-rebase, mid-merge, or mid-cherry-pick
    # from a previous run. Touching a repo in this state is exactly what
    # caused the detached-HEAD / rebase mess we hit before - refuse instead.
    $sGitDir = Join-Path $Path ".git"
    $bRebaseInProgress = (Test-Path (Join-Path $sGitDir "rebase-merge")) -or (Test-Path (Join-Path $sGitDir "rebase-apply"))
    $bMergeInProgress  = Test-Path (Join-Path $sGitDir "MERGE_HEAD")

    if ( $bRebaseInProgress -or $bMergeInProgress ) {
        Write-Error "Repo at $Path has an unfinished rebase or merge. Resolve it manually (git rebase --abort / git merge --abort, or complete it) before re-running this script."
        Add-Log -Tags "#git#sync" -Text "Skipping $Path - unfinished rebase or merge detected"
        $global:SkippedRepos += $Path
        Pop-Location
        return
    } # END if ( $bRebaseInProgress -or $bMergeInProgress )

    # Try git status and capture output
    $sStatusOutput = git status 2>&1
    if ( $sStatusOutput -match "detected dubious ownership" ) {
        Write-Host "Adding $Path as a safe Git directory" -ForegroundColor Green
        Add-Log -Tags "#git#sync" -Text "Marking $Path as a safe Git directory"
        git config --global --add safe.directory "$Path"

        # Re-run git status to confirm it now works
        $sStatusOutput = git status 2>&1
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Error "Git status failed after safe.directory fix"
            $global:SkippedRepos += $Path
            Pop-Location
            return
        }
    } elseif ( $LASTEXITCODE -ne 0 ) {
        Add-Log -Tags "#git#sync" -Text "Git status failed at $Path $sStatusOutput"
        Write-Error "Git status failed: $sStatusOutput"
        $global:SkippedRepos += $Path
        Pop-Location
        return
    }

    git fetch
    if ( $LASTEXITCODE -ne 0 ) {
        Write-Error "Git fetch failed at $Path"
        Add-Log -Tags "#git#sync" -Text "Git fetch failed at $Path"
        $global:SkippedRepos += $Path
        Pop-Location
        return
    }
    Add-Log -Tags "#git#sync" -Text "Fetched remote changes for $Path"

    $sCurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

    # A detached HEAD returns the literal string "HEAD" here - refuse to
    # commit or push against it, since there is no branch to push to.
    if ( $sCurrentBranch -eq "HEAD" ) {
        Write-Error "Repo at $Path is in a detached HEAD state. Checkout a branch before syncing."
        Add-Log -Tags "#git#sync" -Text "Skipping $Path - detached HEAD"
        $global:SkippedRepos += $Path
        Pop-Location
        return
    } # END if ( $sCurrentBranch -eq "HEAD" )

    # Handle a branch that has never been pushed / has no upstream tracking
    # branch yet. Without this, a brand new local branch causes a confusing
    # "pull failed" error instead of simply being published to the remote.
    $sHasUpstream = git rev-parse --abbrev-ref '@{u}' 2> $null
    $bJustSetUpstream = $false

    if ( -not $sHasUpstream ) {
        Write-Host "No upstream tracking branch set for '$sCurrentBranch'. Setting it now." -ForegroundColor Yellow
        Add-Log -Tags "#git#sync" -Text "Setting upstream for $sCurrentBranch at $Path"
        git push --set-upstream origin $sCurrentBranch
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Error "Failed to set upstream for $Path"
            Add-Log -Tags "#git#sync" -Text "Failed to set upstream for $Path"
            $global:SkippedRepos += $Path
            Pop-Location
            return
        }
        $bJustSetUpstream = $true
    }

    $sLocalCommit  = (git rev-parse $sCurrentBranch).Trim()
    $sRemoteCommit = (git rev-parse origin/$sCurrentBranch).Trim()

    if ( $sLocalCommit -ne $sRemoteCommit -and -not $bJustSetUpstream ) {
        Write-Host "Pulling latest changes from remote" -ForegroundColor Green
        Add-Log -Tags "#git#sync" -Text "Pulling changes for $Path"

        # --no-rebase forces a merge, regardless of the local or global
        # pull.rebase setting. Without this, a rebase config elsewhere
        # can silently trigger a rebase here and leave the repo detached.
        git pull origin $sCurrentBranch --no-rebase
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Error "Git pull failed at $Path - resolve conflicts manually, then re-run"
            Add-Log -Tags "#git#sync" -Text "Git pull failed at $Path"
            $global:SkippedRepos += $Path
            Pop-Location
            return
        }
    } elseif ( -not $bJustSetUpstream ) {
        Write-Host "No changes to pull" -ForegroundColor Green
        Add-Log -Tags "#git#sync" -Text "No remote changes to pull for $Path"
    } # END if ( $sLocalCommit -ne $sRemoteCommit )

    # Check if remote is under allowed GitHub accounts (handles SSH + HTTPS)
    $sRemoteUrl = (git config --get remote.origin.url).Trim()

    $sOwner = $null
    if ( $sRemoteUrl -match 'github\.com[:/](?<owner>[^/]+)/' ) {
        $sOwner = $Matches.owner
    }

    $aAllowedOwners = @('david-chase', 'dbc13543')

    if ( $sOwner -and ($aAllowedOwners -contains $sOwner) ) {
        # Check for uncommitted changes
        $sStatus = git status --porcelain
        if ( $sStatus ) {
            Write-Host "Uncommitted changes detected committing changes" -ForegroundColor Green
            git add -A
            git commit -m "Automated commit by Git Sync Script"
            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "Git commit failed at $Path"
                Add-Log -Tags "#git#sync" -Text "Git commit failed at $Path"
                $global:SkippedRepos += $Path
                Pop-Location
                return
            }
        }

        # Push whenever local is ahead of origin - not just when this run
        # happened to commit something - so a commit left behind by a prior
        # failed push doesn't sit unpushed indefinitely.
        $sLocalCommitAfter  = (git rev-parse $sCurrentBranch).Trim()
        $sRemoteCommitAfter = (git rev-parse origin/$sCurrentBranch).Trim()

        if ( $sLocalCommitAfter -ne $sRemoteCommitAfter -and -not $bJustSetUpstream ) {
            Write-Host "Pushing local changes to remote" -ForegroundColor Green
            Add-Log -Tags "#git#sync" -Text "Pushing changes for $Path"
            git push origin $sCurrentBranch
            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "Git push failed at $Path"
                Add-Log -Tags "#git#sync" -Text "Git push failed at $Path"
                $global:SkippedRepos += $Path
                Pop-Location
                return
            }
        } elseif ( -not $bJustSetUpstream ) {
            Write-Host "Nothing to push" -ForegroundColor Green
        }
    } else {
        Write-Host "Skipping push for $Path because remote is not an allowed GitHub account" -ForegroundColor Yellow
        Add-Log -Tags "#git#sync" -Text "Skipping push for $Path (remote owner '$sOwner' not in allowlist)"
    }

    Write-Host "Sync completed for $Path" -ForegroundColor Green
    Add-Log -Tags "#git#sync" -Text "Sync completed for $Path"
    Pop-Location
} # END function Sync-GitRepo

try {
    if ( $All ) {
        Add-Log -Tags "#git#sync" -Text "Syncing all directories in $(Get-Location)"
        $sBasePath = Get-Location
        $aFolders = Get-ChildItem -Path $sBasePath -Directory
        foreach ( $oFolder in $aFolders ) {
            Sync-GitRepo -Path $oFolder.FullName
        } # END foreach
    } else {
        Sync-GitRepo -Path $RepoPath
    } # END if ( $All )

    # Summarize anything that was skipped so failures are never silent
    if ( $global:SkippedRepos.Count -gt 0 ) {
        Write-Host ""
        Write-Host "The following repos were skipped:" -ForegroundColor Yellow
        foreach ( $sSkipped in $global:SkippedRepos ) {
            Write-Host "  - $sSkipped" -ForegroundColor Yellow
        }
    }
}
finally {
    # Return to the original directory and always release the lock,
    # even if something above threw or exited early
    Set-Location -Path $sStartPath
    Remove-Item -Path $sLockPath -Force -ErrorAction SilentlyContinue
}