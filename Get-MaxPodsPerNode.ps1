#-------------------------------------------------------------------
#  Get-MaxPodsPerNode v1
#  Passed a node name, returns the MaxPodsPerNode
#-------------------------------------------------------------------

Param
(
    [string]$node = "<none>",
    [string]$n = "<none>"
) 

Write-Host ""
Write-Host ::: Get-MaxPodsPerNode ::: -ForegroundColor Cyan
Write-Host ""

# Check if user specified -n instead of -node
if( ( $node -eq "<none>" ) -and ( $n -ne "<none>" ) ) {
    $node = $n
} # if( ( $node -eq "<none>" ) -and ( $n -ne "<none>" ) ) {

# No node name was specified, prompt for one
if( $node -eq "<none>" ) {
    kubectl get nodes
    $node = Read-Host -Prompt "Type the name of the node: "
}

kubectl get node $node -ojsonpath='{.status.capacity.pods}'
