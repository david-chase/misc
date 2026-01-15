# Split-Journal.ps1
# Parse a markdown file and split it into 3 outputs

# Construct the input file path using Join-Path for cross-platform compatibility
$inputPath = Join-Path -Path $env:DevFolder -ChildPath "ObsidianPersonal" | 
             Join-Path -ChildPath "Personal Notes" | 
             Join-Path -ChildPath "Journal.md"

# Verify the file exists
if (-not (Test-Path -Path $inputPath)) {
    Write-Error "Input file not found: $inputPath"
    exit 1
}

# Read the file content
$content = Get-Content -Path $inputPath

# Count non-blank lines
$nonBlankLines = $content | Where-Object { $_.Trim() -ne "" }
$nonBlankCount = ($nonBlankLines | Measure-Object).Count

# Output the total number of non-blank lines
Write-Host "Total non-blank lines: $nonBlankCount"

# Prepare output file paths
$outputFolder = Split-Path -Path $inputPath -Parent
$financeJournalPath = Join-Path -Path $outputFolder -ChildPath "Finance Journal.md"
$cookingJournalPath = Join-Path -Path $outputFolder -ChildPath "Cooking Journal.md"
$journal1Path = Join-Path -Path $outputFolder -ChildPath "Journal1.md"

# Initialize arrays for categorized lines
$financeLines = @()
$cookingLines = @()
$otherLines = @()

# Categorize each line
foreach ($line in $content) {
    if ($line -match "#finance|#investment|#stocks|#crypto") {
        $financeLines += $line
    }
    elseif ($line -match "#cooking") {
        $cookingLines += $line
    }
    else {
        $otherLines += $line
    }
}

# Write lines to output files
$financeLines | Set-Content -Path $financeJournalPath -Encoding UTF8
$cookingLines | Set-Content -Path $cookingJournalPath -Encoding UTF8
$otherLines | Set-Content -Path $journal1Path -Encoding UTF8

# Calculate total lines written
$totalLinesWritten = $financeLines.Count + $cookingLines.Count + $otherLines.Count

# Output comparison
Write-Host "Total lines written to output files: $totalLinesWritten"
