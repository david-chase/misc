[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('c')]
    [string]$Command
)

Write-Host 
Write-Host "::: RunAll :::" -ForegroundColor Cyan
Write-Host 

# Default nodes
$nodes = @("192.168.1.100", "192.168.1.101", "192.168.1.102", "192.168.1.103", "192.168.1.104")

# 1. Handle target nodes input
Write-Host "Current target nodes: $($nodes -join ', ')" -ForegroundColor Yellow
$nodeInput = Read-Host "Press ENTER to accept these nodes, or enter a comma-separated list of new nodes"

if (-not [string]::IsNullOrWhiteSpace($nodeInput)) {
    # Split by comma, trim whitespace, and filter out any empty entries
    $nodes = $nodeInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

# 2. Handle command input
if ([string]::IsNullOrWhiteSpace($Command)) {
    $Command = Read-Host "Enter the command to run on all nodes"
}

# Exit if no command was provided via prompt either
if ([string]::IsNullOrWhiteSpace($Command)) {
    Write-Warning "No command specified. Exiting."
    Exit
}

# 3. Execute command on all nodes
foreach ($node in $nodes) {
    Write-Host "Running command on $node..." -ForegroundColor Cyan
    ssh dchase@$node $Command
}