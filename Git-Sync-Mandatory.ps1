# ----------------------------------------------
#  Git-Sync-Mandatory.ps1
#  Reads through a list of repos and clones them if they don't exist or syncs them if they do
# ----------------------------------------------

Write-Host ""
Write-Host "::: Git-Sync-Mandatory :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
if ( [string]::IsNullOrWhiteSpace( $env:SharedFunctions ) -or -not ( Test-Path $env:SharedFunctions ) ) {
    Write-Error "`$env:SharedFunctions is not set or does not exist."
    exit 1
}
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. "./General Functions v1.ps1"
Pop-Location

# Constants for Git identity
$sDefaultGitName = "David Chase"
$sDefaultGitEmail = "dchase@hotmail.com"

# Check if Git is installed
if ( -not ( Get-Command git -ErrorAction SilentlyContinue ) ) {
    Write-Error "Git is not installed or not in the system PATH."
    exit 1
}

# Prevent overlapping runs - if a previous run is still in progress
# (or crashed without cleaning up), skip this run rather than risk two
# processes touching the same repo at once.
$sLockPath = Join-Path $env:Temp "Git-Sync-Mandatory.lock"
if ( Test-Path $sLockPath ) {
    Write-Warning "A previous run appears to still be in progress (lock file present at $sLockPath). Skipping this run."
    Add-Log -Tags "#dev#git#sync" -Text "Skipped run - lock file already present"
    exit 0
}
New-Item -Path $sLockPath -ItemType File -Force | Out-Null

try {

    # Validate Git user configuration and set if missing
    $sGitName = git config --global user.name
    $sGitEmail = git config --global user.email

    if ( [string]::IsNullOrWhiteSpace( $sGitName ) ) {
        Write-Host "Setting Git user.name to '$sDefaultGitName'" -ForegroundColor Green
        git config --global user.name "$sDefaultGitName"
    }

    if ( [string]::IsNullOrWhiteSpace( $sGitEmail ) ) {
        Write-Host "Setting Git user.email to '$sDefaultGitEmail'" -ForegroundColor Green
        git config --global user.email "$sDefaultGitEmail"
    }

    # Confirm DevFolder exists
    if ( -not ( Test-Path $env:DevFolder ) ) {
        Write-Error "`$env:DevFolder is not set or does not exist."
        exit 1
    }

    # Determine CSV paths
    $sDefaultCsvPath = Join-Path $env:DataFiles "Git-Sync-Mandatory.csv"
    $sComputerCsvPath = Join-Path $env:DataFiles "Git-Sync-Mandatory-$env:COMPUTERNAME.csv"

    $aRawUrls = @()

    # Load default CSV if it exists
    if ( Test-Path $sDefaultCsvPath ) {
        $aRawUrls += Get-Content -Path $sDefaultCsvPath
    }

    # Load computer-specific CSV if it exists (Case-insensitive by default in Windows/PowerShell)
    if ( Test-Path $sComputerCsvPath ) {
        Write-Host "Found computer-specific repo list: Git-Sync-Mandatory-$env:COMPUTERNAME.csv" -ForegroundColor Cyan
        $aRawUrls += Get-Content -Path $sComputerCsvPath
    }

    # Clean whitespace, filter blanks, and remove duplicate repositories
    $aRepoUrls = $aRawUrls |
        Where-Object { -not ( [string]::IsNullOrWhiteSpace( $_ ) ) } |
        ForEach-Object { $_.Trim() } |
        Select-Object -Unique

    if ( $aRepoUrls.Count -eq 0 ) {
        Write-Error "No repository URLs found. Ensure at least one valid CSV file exists and contains data."
        exit 1
    }

    foreach ( $sUrl in $aRepoUrls ) {
        # Extract repo name from URL
        if ( $sUrl -match "/([^/]+?)(\.git)?$" ) {
            $sRepoName = $matches[1]
        }
        else {
            Write-Warning "Could not extract repo name from URL: $sUrl"
            continue
        }

        $sLocalPath = Join-Path $env:DevFolder $sRepoName

        if ( -not ( Test-Path $sLocalPath ) ) {
            Add-Log -Tags "#dev#git#sync" -Text ( "Cloning Git repo " + $sUrl + " to " + $sLocalPath )
            Write-Host "`nCloning: $sUrl --> $sLocalPath" -ForegroundColor Green
            git clone $sUrl $sLocalPath
            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "Clone failed for $sUrl - removing partial folder so the next run retries cleanly"
                Add-Log -Tags "#dev#git#sync" -Text ( "Clone failed for " + $sUrl )
                if ( Test-Path $sLocalPath ) {
                    Remove-Item -Path $sLocalPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            continue
        }

        Write-Host "`nProcessing: $sRepoName" -ForegroundColor Green

        # Confirm this is actually a Git repo before running any git commands against it
        if ( -not ( Test-Path -Path ( Join-Path $sLocalPath ".git" ) ) ) {
            Write-Warning "  - $sLocalPath exists but is not a Git repository. Skipping."
            Add-Log -Tags "#dev#git#sync" -Text ( $sLocalPath + " is not a Git repository - skipping" )
            continue
        }

        Push-Location $sLocalPath
        Add-Log -Tags "#dev#git#sync" -Text ( "Syncing Git repo " + $sRepoName )

        # Bail out if the repo is already mid-rebase, mid-merge, or mid-cherry-pick
        # from a previous run. Touching a repo in this state compounds the damage.
        $sGitDir = Join-Path $sLocalPath ".git"
        $bRebaseInProgress = ( Test-Path ( Join-Path $sGitDir "rebase-merge" ) ) -or ( Test-Path ( Join-Path $sGitDir "rebase-apply" ) )
        $bMergeInProgress = Test-Path ( Join-Path $sGitDir "MERGE_HEAD" )

        if ( $bRebaseInProgress -or $bMergeInProgress ) {
            Write-Warning "  - Repo has an unfinished rebase or merge. Skipping until resolved manually."
            Add-Log -Tags "#dev#git#sync" -Text ( "Skipping " + $sRepoName + " - unfinished rebase or merge detected" )
            Pop-Location
            continue
        }

        # Get current branch status
        $sBranch = ( git rev-parse --abbrev-ref HEAD ).Trim()

        # A detached HEAD returns the literal string "HEAD" - refuse to
        # commit or push against it, since there is no branch to push to.
        if ( $sBranch -eq "HEAD" ) {
            Write-Warning "  - Repo is in a detached HEAD state. Skipping until a branch is checked out manually."
            Add-Log -Tags "#dev#git#sync" -Text ( "Skipping " + $sRepoName + " - detached HEAD" )
            Pop-Location
            continue
        }

        $sHasUpstream = git rev-parse --abbrev-ref '@{u}' 2> $null
        $bJustSetUpstream = $false

        if ( -not $sHasUpstream ) {
            Write-Warning "  - No upstream tracking branch set for '$sBranch'. Setting it now."
            git push --set-upstream origin $sBranch
            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "  - Failed to set upstream for $sRepoName"
                Add-Log -Tags "#dev#git#sync" -Text ( "Failed to set upstream for " + $sRepoName )
                Pop-Location
                continue
            }
            $bJustSetUpstream = $true
        }

        # Pull before committing, so any local commit lands on top of an
        # already-current base rather than colliding with it. This order
        # matches git-sync v3 - keep both scripts consistent.
        Write-Host "  - Pulling remote changes..." -ForegroundColor Green
        git fetch
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Error "  - Fetch failed for $sRepoName"
            Add-Log -Tags "#dev#git#sync" -Text ( "Fetch failed for " + $sRepoName )
            Pop-Location
            continue
        }

        git pull origin $sBranch --no-rebase
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Error "  - Pull failed for $sRepoName - resolve conflicts manually, then re-run"
            Add-Log -Tags "#dev#git#sync" -Text ( "Pull failed for " + $sRepoName )
            Pop-Location
            continue
        }

        # Handle local changes
        $sStatus = git status --porcelain
        if ( $sStatus ) {
            Write-Host "  - Staging and committing local changes..." -ForegroundColor Green
            git add .
            git commit -m "Auto-commit by Git-Sync-Mandatory"
            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "  - Commit failed for $sRepoName"
                Add-Log -Tags "#dev#git#sync" -Text ( "Commit failed for " + $sRepoName )
                Pop-Location
                continue
            }
        }
        else {
            Write-Host "  - No local changes to commit." -ForegroundColor Green
        }

        # Push whenever local is ahead of origin - not just when this run
        # happened to commit something. This catches commits left over from
        # a prior run whose push failed, so they never sit unpushed indefinitely.
        $sLocalCommit = ( git rev-parse $sBranch ).Trim()
        $sRemoteCommit = ( git rev-parse "origin/$sBranch" ).Trim()

        if ( $sLocalCommit -ne $sRemoteCommit -and -not $bJustSetUpstream ) {
            Write-Host "  - Pushing local updates..." -ForegroundColor Green
            git push
            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "  - Push failed for $sRepoName"
                Add-Log -Tags "#dev#git#sync" -Text ( "Push failed for " + $sRepoName )
                Pop-Location
                continue
            }
        }
        elseif ( -not $bJustSetUpstream ) {
            Write-Host "  - Nothing to push." -ForegroundColor Green
        }

        Pop-Location
    }

}
finally {
    # Always release the lock, even if something above threw or exited early
    Remove-Item -Path $sLockPath -Force -ErrorAction SilentlyContinue
}