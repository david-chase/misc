param (
    [Parameter(Mandatory = $true, HelpMessage = "The namespace to scan for stuck objects.")]
    [Alias("n", "ns")]
    [string]$Namespace,

    [Parameter(Mandatory = $false)]
    [switch]$Remove
)

$Resources = kubectl api-resources --namespaced=true --verbs=list -o name

foreach ($Resource in $Resources) {
    $StuckObjects = kubectl get $Resource -n $Namespace -o json | ConvertFrom-Json | Where-Object {
        $_.metadata.deletionTimestamp -ne $null -and $_.metadata.finalizers.Count -gt 0
    }

    foreach ($Object in $StuckObjects) {
        $ObjectName = $Object.metadata.name
        
        [PSCustomObject]@{
            Kind       = $Resource
            Name       = $ObjectName
            Namespace  = $Namespace
            Finalizers = $Object.metadata.finalizers -join ', '
            DeletedAt  = $Object.metadata.deletionTimestamp
        }

        if ($Remove) {
            Write-Host "Attempting to remove finalizers for $Resource/$ObjectName..." -ForegroundColor Cyan
            kubectl patch $Resource $ObjectName -n $Namespace --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]'
        }
    }
}