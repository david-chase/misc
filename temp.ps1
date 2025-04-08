Write-Host ""
Write-Host "::: Check-GitMasterSync :::"
Write-Host ""

$devFolder = $env:DevFolder

if ( -not ( Test-Path $devFolder ) ) {
    Write-Host "The path in `\$env:DevFolder` does not exist: $devFolder"
    return
}

Get-ChildItem -Path $devFolder -Directory | ForEach-Object {
    $repoPath = $_.FullName
    $gitFolder = Join-Path -Path $repoPath -ChildPath ".git"

    if ( Test-Path $gitFolder ) {
        Push-Location $repoPath

        try {
            $branchInfo = git symbolic-ref --short HEAD 2>$null
            if ( $branchInfo -eq "master" ) {
                $trackingInfo = git for-each-ref --format="%(upstream:short)" refs/heads/master 2>$null

                if ( $trackingInfo -match "/master$" ) {
                    Write-Host "Synced with master: $repoPath"
                }
            }
        } catch {
            Write-Host "Error processing $repoPath"
        }

        Pop-Location
    }
} # END ForEach-Object


