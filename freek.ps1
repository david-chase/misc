Write-Host ""
Write-Host "::: Get-SystemUsage :::" -ForegroundColor Cyan
Write-Host ""

function Render-Bar {
    param (
        [double]$percent,
        [int]$width = 30
    )

    $filledLength = [math]::Round(($percent / 100) * $width)
    $emptyLength = $width - $filledLength

    $barColor = if ( $percent -le 20 ) { 'Green' } elseif ( $percent -ge 80 ) { 'Red' } else { 'White' }

    $percentStr = "{0,5:N1}%" -f $percent

    Write-Host "$percentStr " -NoNewline
    Write-Host "[" -NoNewline -ForegroundColor Yellow
    Write-Host ('█' * $filledLength) -NoNewline -ForegroundColor $barColor
    Write-Host ('░' * $emptyLength) -NoNewline -ForegroundColor DarkGray
    Write-Host "]" -ForegroundColor Yellow
}

if ( $IsLinux ) {
    # Linux logic
    $memInfo = @{}
    Get-Content /proc/meminfo | ForEach-Object {
        if ($_ -match '^(?<key>\w+):\s+(?<value>\d+)') {
            $memInfo[$matches['key']] = [uint64]$matches['value']
        }
    }

    $totalMemKB = $memInfo['MemTotal']
    $freeMemKB = $memInfo['MemAvailable']
    $usedMemKB = $totalMemKB - $freeMemKB

    $totalMemGB = [math]::Round($totalMemKB / 1MB, 2)
    $usedMemGB = [math]::Round($usedMemKB / 1MB, 2)
    $memPercent = [math]::Round(($usedMemKB / $totalMemKB) * 100, 1)

    $dfOutput = df -BG / | Select-Object -Skip 1 | ForEach-Object {
        ($_ -split '\s+')
    }

    $totalDiskGB = [int]($dfOutput[1] -replace 'G','')
    $usedDiskGB = [int]($dfOutput[2] -replace 'G','')
    $diskPercent = [int]($dfOutput[4] -replace '%','')

} elseif ( $IsWindows ) {
    # Windows logic
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemGB = $totalMemGB - $freeMemGB
    $memPercent = [math]::Round(($usedMemGB / $totalMemGB) * 100, 1)

    $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = 'C:'"
    $totalDiskGB = [math]::Round($drive.Size / 1GB, 2)
    $freeDiskGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    $usedDiskGB = $totalDiskGB - $freeDiskGB
    $diskPercent = [math]::Round(($usedDiskGB / $totalDiskGB) * 100, 1)
}

# Output memory usage
Write-Host "Memory Usage:" -ForegroundColor Yellow
Write-Host ("{0,-20}: {1} GB / {2} GB" -f "Used", $usedMemGB, $totalMemGB)
Write-Host ("{0,-20}: " -f "Utilization") -NoNewline
Render-Bar $memPercent
Write-Host ""

# Output disk usage
Write-Host "Disk Usage:" -ForegroundColor Yellow
Write-Host ("{0,-20}: {1} GB / {2} GB" -f "Used", $usedDiskGB, $totalDiskGB)
Write-Host ("{0,-20}: " -f "Utilization") -NoNewline
Render-Bar $diskPercent
Write-Host ""
