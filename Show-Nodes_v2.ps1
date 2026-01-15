Write-Host ""  # Blank line before script name
Write-Host "::: Show-Nodes :::" -ForegroundColor Cyan
Write-Host ""

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
        [string]$suffix,
        [int]$width = 30
    )

    $barPercent = [math]::Min($percent, 100)
    $filledLength = [math]::Round(($barPercent / 100) * $width)
    $emptyLength = $width - $filledLength

    $barColor = if ( $percent -lt 20 ) { 'Green' } elseif ( $percent -gt 80 ) { 'Red' } else { 'White' }
    $percentStr = "{0,5:N1}%" -f $percent

    Write-Host "$percentStr " -NoNewline
    Write-Host "[" -NoNewline -ForegroundColor Yellow
    Write-Host ('█' * $filledLength) -NoNewline -ForegroundColor $barColor
    Write-Host ('░' * $emptyLength) -NoNewline -ForegroundColor DarkGray
    Write-Host "] " -NoNewline -ForegroundColor Yellow
    Write-Host $suffix
}

# Fetch list of nodes and FILTER OUT cordoned nodes
$nodes = kubectl get nodes -o json | ConvertFrom-Json
$activeNodes = $nodes.items | Where-Object {
    $_.spec.unschedulable -ne $true
}

# Fetch resource usage from metrics server
$metrics = kubectl top nodes --no-headers | ForEach-Object {
    $parts = $_ -split '\s+'

    $cpuRaw = $parts[1]
    $memRaw = $parts[3]

    if ( $cpuRaw -match 'm$' ) {
        $cpuUsage = [int]($cpuRaw -replace 'm', '')
    } else {
        $cpuUsage = [int](1000 * [double]$cpuRaw)
    }

    $memUsage = Convert-MemToMiB $memRaw

    [PSCustomObject]@{
        Name = $parts[0]
        CPU_Usage_millicores = $cpuUsage
        Memory_Usage_Mi = $memUsage
    }
}

# Get pod reservations (requests) for all pods
$podList = kubectl get pods --all-namespaces -o json | ConvertFrom-Json
$activeNodeNames = $activeNodes.metadata.name
$podRequestsByNode = @{}

foreach ( $pod in $podList.items ) {
    $nodeName = $pod.spec.nodeName
    if ( -not $nodeName ) { continue }
    if ( $activeNodeNames -notcontains $nodeName ) { continue }

    $totalCpu = 0
    $totalMem = 0

    $allContainers = @()
    if ( $pod.spec.containers ) { $allContainers += $pod.spec.containers }
    if ( $pod.spec.initContainers ) { $allContainers += $pod.spec.initContainers }

    foreach ( $container in $allContainers ) {
        if ( $container.resources.requests.cpu ) {
            $totalCpu += Convert-CpuToMillicores $container.resources.requests.cpu
        }
        if ( $container.resources.requests.memory ) {
            $totalMem += Convert-MemToMiB $container.resources.requests.memory
        }
    }

    if ( $pod.spec.overhead.cpu ) {
        $totalCpu += Convert-CpuToMillicores $pod.spec.overhead.cpu
    }
    if ( $pod.spec.overhead.memory ) {
        $totalMem += Convert-MemToMiB $pod.spec.overhead.memory
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

# Cluster totals accumulators
$clusterAllocCPU = 0
$clusterAllocMem = 0
$clusterReqCPU = 0
$clusterReqMem = 0
$clusterUseCPU = 0
$clusterUseMem = 0

# Output per active node
foreach ( $node in $activeNodes ) {
    $name = $node.metadata.name
    $allocatable = $node.status.allocatable

    $allocCPU = Convert-CpuToMillicores $allocatable.cpu
    $allocMem = Convert-MemToMiB $allocatable.memory

    $reqCPU = 0
    $reqMem = 0
    if ( $podRequestsByNode.ContainsKey($name) ) {
        $reqCPU = $podRequestsByNode[$name].CPU_Requests_millicores
        $reqMem = $podRequestsByNode[$name].Memory_Requests_Mi
    }

    $cpuUsage = ($metrics | Where-Object { $_.Name -eq $name } | Select-Object -First 1 -ExpandProperty CPU_Usage_millicores)
    $memUsage = ($metrics | Where-Object { $_.Name -eq $name } | Select-Object -First 1 -ExpandProperty Memory_Usage_Mi)

    if ( $null -eq $cpuUsage ) { $cpuUsage = 0 }
    if ( $null -eq $memUsage ) { $memUsage = 0 }

    $clusterAllocCPU += $allocCPU
    $clusterAllocMem += $allocMem
    $clusterReqCPU += $reqCPU
    $clusterReqMem += $reqMem
    $clusterUseCPU += $cpuUsage
    $clusterUseMem += $memUsage

    $cpuReqPercent = if ( $allocCPU -gt 0 ) { [Math]::Min(100, (100 * $reqCPU / $allocCPU)) } else { 0 }
    $cpuUsagePercent = if ( $allocCPU -gt 0 ) { [Math]::Min(100, (100 * $cpuUsage / $allocCPU)) } else { 0 }

    $memReqPercent = if ( $allocMem -gt 0 ) { [Math]::Min(100, (100 * $reqMem / $allocMem)) } else { 0 }
    $memUsagePercent = if ( $allocMem -gt 0 ) { [Math]::Min(100, (100 * $memUsage / $allocMem)) } else { 0 }

    $cpuReqSuffix = "[{0:N0}m / {1:N0}m]" -f $reqCPU, $allocCPU
    $cpuUsageSuffix = "[{0:N0}m / {1:N0}m]" -f $cpuUsage, $allocCPU

    $memReqSuffix = "[{0:N0}Gi / {1:N0}Gi]" -f ($reqMem / 1024), ($allocMem / 1024)
    $memUsageSuffix = "[{0:N0}Gi / {1:N0}Gi]" -f ($memUsage / 1024), ($allocMem / 1024)

    Write-Host ""
    Write-Host "Node: $name (Allocatable: $([Math]::Round( $allocCPU / 1000, 2 )) cores, $([Math]::Round( $allocMem / 1024, 2 )) GiB)" -ForegroundColor Yellow
    Write-Host ("{0,-20}: " -f "CPU Reserved") -NoNewline
    Render-Bar $cpuReqPercent $cpuReqSuffix
    Write-Host ("{0,-20}: " -f "CPU Utilization") -NoNewline
    Render-Bar $cpuUsagePercent $cpuUsageSuffix
    Write-Host ("{0,-20}: " -f "Memory Reserved") -NoNewline
    Render-Bar $memReqPercent $memReqSuffix
    Write-Host ("{0,-20}: " -f "Memory Utilization") -NoNewline
    Render-Bar $memUsagePercent $memUsageSuffix
}

Write-Host ""
Write-Host " ---"
Write-Host ""

Write-Host "Cluster Totals" -ForegroundColor Cyan

$cpuReqPercentTotal = if ( $clusterAllocCPU -gt 0 ) { (100 * $clusterReqCPU / $clusterAllocCPU) } else { 0 }
$cpuUsagePercentTotal = if ( $clusterAllocCPU -gt 0 ) { (100 * $clusterUseCPU / $clusterAllocCPU) } else { 0 }

$memReqPercentTotal = if ( $clusterAllocMem -gt 0 ) { (100 * $clusterReqMem / $clusterAllocMem) } else { 0 }
$memUsagePercentTotal = if ( $clusterAllocMem -gt 0 ) { (100 * $clusterUseMem / $clusterAllocMem) } else { 0 }

$cpuReqSuffixTotal = "[{0:N0}m / {1:N0}m]" -f $clusterReqCPU, $clusterAllocCPU
$cpuUsageSuffixTotal = "[{0:N0}m / {1:N0}m]" -f $clusterUseCPU, $clusterAllocCPU

$memReqSuffixTotal = "[{0:N0}Gi / {1:N0}Gi]" -f ($clusterReqMem / 1024), ($clusterAllocMem / 1024)
$memUsageSuffixTotal = "[{0:N0}Gi / {1:N0}Gi]" -f ($clusterUseMem / 1024), ($clusterAllocMem / 1024)

Write-Host ("{0,-20}: " -f "CPU Reserved") -NoNewline
Render-Bar $cpuReqPercentTotal $cpuReqSuffixTotal

Write-Host ("{0,-20}: " -f "CPU Utilization") -NoNewline
Render-Bar $cpuUsagePercentTotal $cpuUsageSuffixTotal

Write-Host ("{0,-20}: " -f "Memory Reserved") -NoNewline
Render-Bar $memReqPercentTotal $memReqSuffixTotal

Write-Host ("{0,-20}: " -f "Memory Utilization") -NoNewline
Render-Bar $memUsagePercentTotal $memUsageSuffixTotal
Write-Host ""
