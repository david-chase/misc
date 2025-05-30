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
Pop-Location # END Pop-Location

# Constants for Git identity
$defaultGitName = "David Chase"
$defaultGitEmail = "dchase@hotmail.com"

# Check if Git is installed
if ( -not ( Get-Command git -ErrorAction SilentlyContinue ) ) {
    Write-Error "Git is not installed or not in the system PATH."
    exit 1
} # END if ( -not ( Get-Command git -ErrorAction SilentlyContinue ) )

# Validate Git user configuration and set if missing
$gitName = git config --global user.name
$gitEmail = git config --global user.email

if ( [string]::IsNullOrWhiteSpace( $gitName ) ) {
    Write-Host "Setting Git user.name to '$defaultGitName'"
    git config --global user.name "$defaultGitName"
} # END if ( [string]::IsNullOrWhiteSpace( $gitName ) )

if ( [string]::IsNullOrWhiteSpace( $gitEmail ) ) {
    Write-Host "Setting Git user.email to '$defaultGitEmail'"
    git config --global user.email "$defaultGitEmail"
} # END if ( [string]::IsNullOrWhiteSpace( $gitEmail ) )

# Confirm DevFolder exists
if ( -not ( Test-Path $env:DevFolder ) ) {
    Write-Error "`$env:DevFolder is not set or does not exist."
    exit 1
} # END if ( -not ( Test-Path $env:DevFolder ) )

# Determine script and CSV paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseCsvPath = Join-Path $env:DataFiles "Git-Sync-Mandatory.csv"

# Host-specific override (use lowercase $env:HOSTNAME)
$hostName = $env:HOSTNAME.ToLowerInvariant()
$hostCsvName = "Git-Sync-Mandatory-$hostName.csv"
$hostCsvPath = Join-Path $env:DataFiles $hostCsvName

# Validate base CSV exists
if ( -not ( Test-Path $baseCsvPath ) ) {
    Write-Error "Required CSV file not found: $baseCsvPath"
    exit 1
} # END if ( -not ( Test-Path $baseCsvPath ) )

# Read base CSV
$repoUrls = Get-Content -Path $baseCsvPath | Where-Object { -not ( [string]::IsNullOrWhiteSpace( $_ ) ) } # END Where-Object

# Append host-specific CSV if found
if ( Test-Path $hostCsvPath ) {
    Write-Host "`nLoading host-specific override file: $hostCsvPath"
    $hostUrls = Get-Content -Path $hostCsvPath | Where-Object { -not ( [string]::IsNullOrWhiteSpace( $_ ) ) } # END Where-Object
    $repoUrls += $hostUrls
} # END if ( Test-Path $hostCsvPath )

# Remove duplicates (case-insensitive)
$repoUrls = $repoUrls | Sort-Object { $_.ToLowerInvariant() } | Select-Object -Unique

foreach ( $url in $repoUrls ) {
    $url = $url.Trim()

    # Convert HTTPS to SSH if on Linux
    if ( $IsLinux -and $url -match "^https://([^/]+)/([^/]+)/(.+?)(\.git)?$" ) {
        $domain = $matches[1]
        $user = $matches[2]
        $repo = $matches[3]
        $url = "git@${domain}:${user}/${repo}.git"
        Write-Host "Converted to SSH: $url"
    } # END if ( $IsLinux -and $url -match ... )

    # Extract repo name from URL
    if ( $url -match "/([^/]+?)(\.git)?$" ) {
        $repoName = $matches[1]
    } # END if ( $url -match "/([^/]+?)(\.git)?$" )
    else {
        Write-Warning "Could not extract repo name from URL: $url"
        continue
    } # END else

    $localPath = Join-Path $env:DevFolder $repoName

    if ( -not ( Test-Path $localPath ) ) {
        Add-Log -Tags "#dev#git#sync" -Text ( "Cloning Git repo " + $url + " to " + $localPath )
        Write-Host "`nCloning: $url --> $localPath"
        git clone $url $localPath
    } # END if ( -not ( Test-Path $localPath ) )
    else {
        Write-Host "`nProcessing: $repoName"
        Push-Location $localPath

        # Stage any changes
        $status = git status --porcelain
        Add-Log -Tags "#dev#git#sync" -Text ( "Syncing Git repo " + $repoName )
        if ( $status ) {
            Write-Host "  - Staging and committing local changes..."
            git add .
            git commit -m "Auto-commit by Git-Sync-Mandatory" 2> $null
            if ( $LASTEXITCODE -eq 0 ) {
                # Ensure branch is up-to-date before pushing
                $branch = git rev-parse --abbrev-ref HEAD
                $hasUpstream = git rev-parse --abbrev-ref '@{u}' 2> $null

                if ( $hasUpstream ) {
                    Write-Host "  - Pulling remote changes before pushing..."
                    git pull --rebase
                }
                else {
                    Write-Warning "  - No upstream tracking branch set for '$branch'. Setting it now."
                    git push --set-upstream origin $branch
                    git pull --rebase
                }

                git push
            } # END if ( $LASTEXITCODE -eq 0 )
            else {
                Write-Host "  - No staged changes to commit."
            } # END else
        } # END if ( $status )
        else {
            Write-Host "  - No local changes to commit."
        } # END else

        # Check if current branch has upstream
        $branch = git rev-parse --abbrev-ref HEAD
        $hasUpstream = git rev-parse --abbrev-ref '@{u}' 2> $null

        if ( $hasUpstream ) {
            Write-Host "  - Pulling remote changes..."
            git pull --rebase
        }
        else {
            Write-Warning "  - No upstream tracking branch set for '$branch'. Setting it now."
            git push --set-upstream origin $branch
            git pull --rebase
        }

        Pop-Location # END Pop-Location
    } # END else
} # END foreach ( $url in $repoUrls )
