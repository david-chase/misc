# ----------------------------------------------
#  Git-Sync-Mandatory.ps1
#  Reads through a list of repos and clones them if they don't exist or syncs them if they do
# ----------------------------------------------

Write-Host ""
Write-Host "::: Git-Sync-Mandatory :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. "./General Functions v1.ps1"
Pop-Location 

# Constants for Git identity
$defaultGitName = "David Chase"
$defaultGitEmail = "dchase@hotmail.com"

# Check if Git is installed
if ( -not ( Get-Command git -ErrorAction SilentlyContinue ) ) {
    Write-Error "Git is not installed or not in the system PATH."
    exit 1
} 

# Validate Git user configuration and set if missing
$gitName = git config --global user.name
$gitEmail = git config --global user.email

if ( [string]::IsNullOrWhiteSpace( $gitName ) ) {
    Write-Host "Setting Git user.name to '$defaultGitName'"
    git config --global user.name "$defaultGitName"
} 

if ( [string]::IsNullOrWhiteSpace( $gitEmail ) ) {
    Write-Host "Setting Git user.email to '$defaultGitEmail'"
    git config --global user.email "$defaultGitEmail"
} 

# Confirm DevFolder exists
if ( -not ( Test-Path $env:DevFolder ) ) {
    Write-Error "`$env:DevFolder is not set or does not exist."
    exit 1
} 

# Determine script and CSV paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultCsvPath = Join-Path $env:DataFiles "Git-Sync-Mandatory.csv"
$computerCsvPath = Join-Path $env:DataFiles "Git-Sync-Mandatory-$env:COMPUTERNAME.csv"

$rawUrls = @()

# Load default CSV if it exists
if ( Test-Path $defaultCsvPath ) {
    $rawUrls += Get-Content -Path $defaultCsvPath
}

# Load computer-specific CSV if it exists (Case-insensitive by default in Windows/PowerShell)
if ( Test-Path $computerCsvPath ) {
    Write-Host "Found computer-specific repo list: Git-Sync-Mandatory-$env:COMPUTERNAME.csv" -ForegroundColor Cyan
    $rawUrls += Get-Content -Path $computerCsvPath
}

# Clean whitespace, filter blanks, and remove duplicate repositories
$repoUrls = $rawUrls | 
    Where-Object { -not ( [string]::IsNullOrWhiteSpace( $_ ) ) } | 
    ForEach-Object { $_.Trim() } | 
    Select-Object -Unique

if ( $repoUrls.Count -eq 0 ) {
    Write-Error "No repository URLs found. Ensure at least one valid CSV file exists and contains data."
    exit 1
}

foreach ( $url in $repoUrls ) {
    # Extract repo name from URL
    if ( $url -match "/([^/]+?)(\.git)?$" ) {
        $repoName = $matches[1]
    } 
    else {
        Write-Warning "Could not extract repo name from URL: $url"
        continue
    } 

    $localPath = Join-Path $env:DevFolder $repoName

    if ( -not ( Test-Path $localPath ) ) {
        Add-Log -Tags "#dev#git#sync" -Text ( "Cloning Git repo " + $url + " to " + $localPath )
        Write-Host "`nCloning: $url --> $localPath"
        git clone $url $localPath
    } 
    else {
        Write-Host "`nProcessing: $repoName"
        Push-Location $localPath
        Add-Log -Tags "#dev#git#sync" -Text ( "Syncing Git repo " + $repoName )

        # Get current branch status
        $branch = git rev-parse --abbrev-ref HEAD
        $hasUpstream = git rev-parse --abbrev-ref '@{u}' 2> $null
        $status = git status --porcelain

        # Handle local changes
        if ( $status ) {
            Write-Host "  - Staging and committing local changes..."
            git add .
            git commit -m "Auto-commit by Git-Sync-Mandatory" 2> $null
        }
        else {
            Write-Host "  - No local changes to commit."
        }

        # Handle Sync (Pull / Push)
        if ( $hasUpstream ) {
            Write-Host "  - Pulling remote changes..."
            git pull --rebase
        }
        else {
            Write-Warning "  - No upstream tracking branch set for '$branch'. Setting it now."
            git push --set-upstream origin $branch
            git pull --rebase
        }

        # Push if we committed changes locally
        if ( $status ) {
            Write-Host "  - Pushing local updates..."
            git push
        }

        Pop-Location 
    } 
}
