
Write-Host "::: CheckMasterBranches.ps1 :::" -ForegroundColor Cyan

# Your GitHub username
$GitHubUsername = "david-chase"

# Your GitHub Personal Access Token (hardcoded)
$TokenEncoded = "Z2hwXzdPWUlhcFhZUzkxWXZYdm45M2RpQ3RKOHRBTERkWTRmRnM1VA=="
$bytes = [System.Convert]::FromBase64String( $TokenEncoded )
$TokenPlainText = [System.Text.Encoding]::UTF8.GetString( $bytes )

# GitHub API base URL
$GitHubApiUrl = "https://api.github.com"

# Set headers for authentication
$Headers = @{
    Authorization = "token $TokenPlainText"
    "User-Agent"  = "$GitHubUsername"
    Accept        = "application/vnd.github+json"
}

# Get all repositories for the user
$ReposUrl = "$GitHubApiUrl/user/repos?per_page=100"
$AllRepos = @()

do {
    $Response = Invoke-RestMethod -Uri $ReposUrl -Headers $Headers -Method Get
    $AllRepos += $Response
    $Links = ($Response.PSObject.Properties["Link"] | Select-Object -ExpandProperty Value)
    $ReposUrl = if ($Links -match '<(.+?)>; rel="next"') { $matches[1] } else { $null }
} while ( $ReposUrl )

# Check each repo for a branch named "master"
$ReposWithMaster = @()

foreach ( $Repo in $AllRepos ) {
    $BranchesUrl = $Repo.branches_url -replace '{/branch}', ''
    $Branches = Invoke-RestMethod -Uri $BranchesUrl -Headers $Headers -Method Get

    foreach ( $Branch in $Branches ) {
        if ( $Branch.name -eq "master" ) {
            $ReposWithMaster += $Repo.full_name
            break
        } # END if ( $Branch.name -eq "master" )
    } # END foreach ( $Branch in $Branches )
} # END foreach ( $Repo in $AllRepos )

# Output results
if ( $ReposWithMaster.Count -gt 0 ) {
    Write-Host "`nRepositories with a 'master' branch:`n" -ForegroundColor Yellow
    $ReposWithMaster | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "`nNo repositories with a 'master' branch found." -ForegroundColor Green
}
