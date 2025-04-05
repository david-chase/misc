param (
    [string]$namespace,
    [string]$n
 )

Write-Host ""
Write-Host ::: Get-MaxPodsPerNode v2 ::: -ForegroundColor Cyan
# Write-Host ""

$sRawOutput = kubectl get no
$aNodes = @()
# Write-Host $sRawOutput.Length
for( $i = 1; $i -le ( $sRawOutput.Length - 1 ); $i++ ) {
    $aNodes += [PSCustomObject]@{ node = $sRawOutput[ $i ].Split( " " )[ 0 ]; maxpods = "" }
}

foreach( $oNode in $aNodes) {
    $sRawOutput = kubectl get node ( $oNode.node ) -ojsonpath='{.status.capacity.pods}'
    $oNode.maxpods = $sRawOutput
} # foreach( $oNode in $aNodes)
$aNodes | Out-Host