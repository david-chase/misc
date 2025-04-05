# Define the CSV file path relative to the script location
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$csvFile = Join-Path $env:DataFiles "apps.csv"

# Read the CSV file
$apps = Import-Csv -Path $csvFile

# Initialize an array for valid apps
$validApps = @()

# Process each app entry
foreach ($app in $apps) {
    # Expand environment variables in the command path
    $expandedCommand = [System.Environment]::ExpandEnvironmentVariables($app.Command)
    
    # Check if the application exists
    if (Test-Path $expandedCommand -PathType Leaf) {
        # Store valid app details
        $validApps += [PSCustomObject]@{
            ShortName    = $app.ShortName
            Description  = $app.Description
            Command      = $expandedCommand
        }
    }
}

# Sort the list by ShortName
$validApps = $validApps | Sort-Object ShortName

# Display the app list with only ShortName and Description
Write-Host "`n::: PowerShell Menu :::`n" -ForegroundColor Cyan
$validApps | Select-Object ShortName, Description | Format-Table -AutoSize

# Create aliases for valid applications
foreach ($app in $validApps) {
    Set-Alias -Name $app.ShortName -Value $app.Command -Scope Global -Force
}
