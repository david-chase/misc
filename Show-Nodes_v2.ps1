
Write-Host ""  # Blank line before script name
Write-Host "::: Show-Nodes :::" -ForegroundColor Cyan

function Convert-CpuToMillicores ( $value ) {
    if ( $value -match 'm$' ) {
        return [int]($value -replace 'm', '')
    } else {
        return [int](1000 * [double]$value)
    }
}

function Convert-MemToMiB ( $value ) {
    if ( $value -match 'Ki$' ) {
        return [int]([double]($value -replace 'Ki', '') / 1024)
    } elseif ( $value -match 'Mi$' ) {
        return [int]($value -replace 'Mi', '')
    } elseif ( $value -match 'Gi$' ) {
        return [int]($value -replace 'Gi', '') * 1024
    } elseif ( $value -match '^[0-9]+$' ) {
        return [int]([double]$value / 1024 / 1024)
    } else {
        return 0
    }
}

function Render-Bar {
    param (
        [double]$percent,
        [int]$width = 30
    )

    $filledLength = [math]::Round(($percent / 100) * $width)
    $emptyLength = $width - $filledLength

    $barColor = if ( $percent -lt 20 ) { 'Green' } elseif ( $percent -gt 80 ) { 'Red' } else { 'White' }

    $percentStr = "{0,5:N1}%" -f $percent

    Write-Host "$percentStr " -NoNewline
    Write-Host "[" -NoNewline -ForegroundColor Yellow
    Write-Host ('█' * $filledLength) -NoNewline -ForegroundColor $barColor
    Write-Host ('░' * $emptyLength) -NoNewline -ForegroundColor DarkGray
    Write-Host "]" -ForegroundColor Yellow
}

# Fetch list of nodes
$nodes = kubectl get nodes -o json | ConvertFrom-Json

# Fetch resource usage from metrics server
$metrics = kubectl top nodes --no-headers | ForEach-Object {
    $parts = $_ -split '\s+'

    $cpuRaw = $parts[1]
    $memRaw = $parts[2]

    if ( $cpuRaw -match 'm$' ) {
        $cpuUsage = [int]($cpuRaw -replace 'm', '')
    } else {
        $cpuUsage = [int](1000 * [double]$cpuRaw)
    }

    $memUsage = [int]($memRaw -replace '[^0-9]', '')

    [PSCustomObject]@{
        Name = $parts[0]
        CPU_Usage_millicores = $cpuUsage
        Memory_Usage_Mi = $memUsage
    }
}

# Get pod reservations (requests) for all pods
$podList = kubectl get pods --all-namespaces -o json | ConvertFrom-Json

# Group reservations by node
$podRequestsByNode = @{}

foreach ( $pod in $podList.items ) {
    $nodeName = $pod.spec.nodeName
    if ( -not $nodeName ) { continue }

    $totalCpu = 0
    $totalMem = 0

    $allContainers = @()
    if ( $pod.spec.containers ) { $allContainers += $pod.spec.containers }
    if ( $pod.spec.initContainers ) { $allContainers += $pod.spec.initContainers }

    foreach ( $container in $allContainers ) {
        $cpuReq = 0
        $memReq = 0

        if ( $container.resources.requests.cpu ) {
            $cpuReq = Convert-CpuToMillicores $container.resources.requests.cpu
        }

        if ( $container.resources.requests.memory ) {
            $memReq = Convert-MemToMiB $container.resources.requests.memory
        }

        $totalCpu += $cpuReq
        $totalMem += $memReq
    }

    if ( $pod.spec.overhead.memory ) {
        $totalMem += Convert-MemToMiB $pod.spec.overhead.memory
    }
    if ( $pod.spec.overhead.cpu ) {
        $totalCpu += Convert-CpuToMillicores $pod.spec.overhead.cpu
    }

    if ( -not $podRequestsByNode.ContainsKey($nodeName) ) {
        $podRequestsByNode[$nodeName] = [PSCustomObject]@{
            CPU_Requests_millicores = 0
            Memory_Requests_Mi = 0
        }
    }

    $podRequestsByNode[$nodeName].CPU_Requests_millicores += $totalCpu
    $podRequestsByNode[$nodeName].Memory_Requests_Mi += $totalMem
}

# Output result per node with colored bars
foreach ( $node in $nodes.items ) {
    $name = $node.metadata.name
    $allocatable = $node.status.allocatable

    $allocCPU = Convert-CpuToMillicores $allocatable.cpu
    $allocMem = Convert-MemToMiB $allocatable.memory

    $reqCPU = $podRequestsByNode[$name].CPU_Requests_millicores
    $reqMem = $podRequestsByNode[$name].Memory_Requests_Mi

    $cpuUsage = $metrics | Where-Object { $_.Name -eq $name } | Select-Object -ExpandProperty CPU_Usage_millicores
    $memUsage = $metrics | Where-Object { $_.Name -eq $name } | Select-Object -ExpandProperty Memory_Usage_Mi

    $cpuReqPercent = if ( $allocCPU -gt 0 ) { (100 * $reqCPU / $allocCPU) } else { 0 }
    $cpuUsagePercent = if ( $allocCPU -gt 0 ) { (100 * $cpuUsage / $allocCPU) } else { 0 }

    $memReqPercent = if ( $allocMem -gt 0 ) { (100 * $reqMem / $allocMem) } else { 0 }
    $memUsagePercent = if ( $allocMem -gt 0 ) { (100 * $memUsage / $allocMem) } else { 0 }

    Write-Host ""
    Write-Host "Node: $name" -ForegroundColor Yellow
    Write-Host ("{0,-20}: " -f "CPU Reserved") -NoNewline
    Render-Bar $cpuReqPercent
    Write-Host ("{0,-20}: " -f "CPU Utilization") -NoNewline
    Render-Bar $cpuUsagePercent
    Write-Host ("{0,-20}: " -f "Memory Reserved") -NoNewline
    Render-Bar $memReqPercent
    Write-Host ("{0,-20}: " -f "Memory Utilization") -NoNewline
    Render-Bar $memUsagePercent
}
