param (
    [Parameter(Mandatory = $true)]
    [Alias("n", "ns")]
    [string]$Namespace,

    [Parameter(Mandatory = $false)]
    [switch]$Remove
)

# Identify all namespaced resource types
$Resources = kubectl api-resources --namespaced=true --verbs=list -o name

foreach ($Resource in $Resources) {
    # Get objects that have a deletion timestamp (stuck in termination)
    $StuckObjects = kubectl get $Resource -n $Namespace -o json 2>$null | ConvertFrom-Json | Where-Object {
        $_.metadata.deletionTimestamp -ne $null
    }

    # Handle both single objects and arrays returned by the API
    $ObjectList = if ($StuckObjects.items) { $StuckObjects.items } else { $StuckObjects }

    foreach ($Object in $ObjectList) {
        if ($null -ne $Object.metadata.name) {
            $Name = $Object.metadata.name
            
            [PSCustomObject]@{
                Kind      = $Resource
                Name      = $Name
                Namespace = $Namespace
                Status    = "Terminating"
            }

            if ($Remove) {
                Write-Host "Patching $Resource/$Name to remove finalizers..." -ForegroundColor Cyan
                # Using Merge Patch with null to clear the finalizers array
                kubectl patch $Resource $Name -n $Namespace --type merge -p '{"metadata":{"finalizers":null}}'
            }
        }
    }
}