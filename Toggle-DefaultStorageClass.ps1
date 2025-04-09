param (
    [string]$StorageClassName
)

Write-Host ""
Write-Host "::: Toggle-DefaultStorageClass :::" -ForegroundColor Cyan
Write-Host ""

Write-Host ""

if ( -not $StorageClassName ) {
    Write-Host "No StorageClass name provided. Listing all StorageClasses and their default status..."
    Write-Host ""

    $scList = kubectl get storageclass -o json | ConvertFrom-Json

    foreach ( $sc in $scList.items ) {
        $name = $sc.metadata.name
        $isDefault = $sc.metadata.annotations.'storageclass.kubernetes.io/is-default-class'

        if ( $isDefault -eq "true" ) {
            Write-Host "$name`t[DEFAULT]" -ForegroundColor Green
        } else {
            Write-Host "$name`t[non-default]"
        } # END if ( $isDefault -eq "true" )
    } # END foreach ( $sc in $scList.items )

    Write-Host ""
    exit 0
} # END if ( -not $StorageClassName )

# Check if the StorageClass exists
$sc = kubectl get storageclass $StorageClassName -o json 2>$null

if ( -not $sc ) {
    Write-Error "StorageClass '$StorageClassName' not found."
    exit 1
} # END if ( -not $sc )

# Parse the JSON output
$scObj = $sc | ConvertFrom-Json
$currentAnnotation = $scObj.metadata.annotations.'storageclass.kubernetes.io/is-default-class'

# Determine current value
if ( $null -eq $currentAnnotation -or $currentAnnotation -eq "false" ) {
    $newAnnotation = "true"
    Write-Host "Setting '$StorageClassName' as the default StorageClass..."
} else {
    $newAnnotation = "false"
    Write-Host "Unsetting '$StorageClassName' as the default StorageClass..."
} # END if ( $null -eq $currentAnnotation -or $currentAnnotation -eq "false" )

# Patch the annotation
$patch = @{
    metadata = @{
        annotations = @{
            "storageclass.kubernetes.io/is-default-class" = $newAnnotation
        }
    }
} | ConvertTo-Json -Depth 5

kubectl patch storageclass $StorageClassName -p $patch
