# Get all snapshots and parse the output
$rawOutput = sudo timeshift --list

# Regex to find the timestamp pattern: 2026-03-29_17-15-23
$snapshots = $rawOutput | Select-String -Pattern "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}"

if (-not $snapshots) {
    Write-Host "No snapshots found or unable to parse Timeshift output."
    exit
}

# Display current snapshots for context
Write-Host "Current snapshots found:"
$snapshots | ForEach-Object { Write-Host $_.Line }

# Prompt for the number of snapshots to keep
$userInput = Read-Host "Enter the number of recent snapshots you want to keep"

# Validation: Check if the input is a valid integer
$keepCount = $userInput -as [int]

if ($null -eq $keepCount) {
    Write-Host "Error: '$userInput' is not a valid integer. Exiting."
    exit
}

# Calculate how many need to be deleted
$totalSnapshots = $snapshots.Count
$deleteCount = $totalSnapshots - $keepCount

if ($deleteCount -le 0) {
    Write-Host "You are keeping $keepCount snapshots, which is equal to or greater than the current count ($totalSnapshots). No action taken."
    exit
}

# Extract the Snapshot Tags (dates) and sort them
$snapshotTags = $snapshots | ForEach-Object {
    if ($_.Matches.Value) {
        return $_.Matches.Value
    }
} | Sort-Object

# Select the oldest ones for deletion
$toDelete = $snapshotTags | Select-Object -First $deleteCount

Write-Host "Deleting $deleteCount oldest snapshots..."

foreach ($tag in $toDelete) {
    Write-Host "Removing snapshot: $tag"
    # Execute the timeshift delete command with sudo
    sudo timeshift --delete --snapshot $tag --scripted
}

Write-Host "Cleanup complete."
