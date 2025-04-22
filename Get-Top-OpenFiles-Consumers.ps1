Get-Process | ForEach-Object {
    $procId = $_.Id
    $name = $_.ProcessName
    try {
        $fdPath = "/proc/$procId/fd"
        if (Test-Path $fdPath) {
            $openCount = (Get-ChildItem $fdPath -ErrorAction Stop).Count
            [PSCustomObject]@{
                ProcessId = $procId
                Name      = $name
                OpenFiles = $openCount
            }
        }
    } catch {
        # Silently skip inaccessible processes
    }
} | Sort-Object OpenFiles -Descending | Select-Object -First 20
