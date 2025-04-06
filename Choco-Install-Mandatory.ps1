Write-Host ""
Write-Host "::: Choco-Install-Mandatory :::" -ForegroundColor Cyan
Write-Host ""

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. "./General Functions v1.ps1"
Pop-Location # END Pop-Location

# Choco-Install-Mandatory.ps1

# Check for Administrator rights
If ( -Not ( [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ) ) {
    Write-Warning "You must run this script as Administrator."
    Exit 1
} # END if ( -Not Administrator )

Add-Log -Tags "#choco#packages" -Text ( "Running Choco-Install-Mandatory" )

# Expand %DataFiles% environment variable
$csvPath = "$env:DataFiles\Choco-Install-Mandatory.csv"

If ( -Not ( Test-Path -Path $csvPath ) ) {
    Add-Log -Tags "#choco#packages" -Text ( "ERROR: Could not find Choco-Install-Mandatory.csv" )
    Write-Warning "CSV file not found at: $csvPath"
    Exit 1
} # END if ( -Not Test-Path )

# Import package list
$packageList = Import-Csv -Path $csvPath

# Ensure each entry has a 'PackageName' column
If ( -Not ( $packageList | Get-Member -Name "PackageName" ) ) {
    Write-Warning "CSV file must contain a 'PackageName' column."
    Exit 1
} # END if ( -Not CSV column check )

# Process each package
ForEach ( $pkg in $packageList ) {
    $pkgName = $pkg.PackageName

    # Check if package is installed
    $installedInfo = choco list --local-only --exact $pkgName --limit-output 2>$null
    $installed = $installedInfo -match "^$pkgName\|"

    If ( -Not $installed ) {
        Add-Log -Tags "#choco#packages" -Text ( "Installing package " + $pkgName )
        Write-Host "Installing package: $pkgName"
        choco install $pkgName -y
    } # END if ( -Not $installed )
    Else {
        # Check for outdated version
        $outdated = choco outdated | Select-String "^$pkgName"

        If ( $outdated ) {
            Add-Log -Tags "#choco#packages" -Text ( "Upgrading package " + $pkgName )
            Write-Host "Upgrading package: $pkgName"
            choco upgrade $pkgName -y
        } # END if ( $outdated )
        Else {
            Write-Host "Package '$pkgName' is already up to date."
        } # END else (up-to-date)
    } # END else (installed)
} # END foreach ( $pkg in $packageList )
