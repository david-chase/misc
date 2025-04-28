
# ::: Get-Pending.ps1 :::

# Define the command
$kubectlCommand = 'kubectl get pods --all-namespaces --field-selector=status.phase=Pending'

# Show the command in green
Write-Host "Running command:" -ForegroundColor Green
Write-Host $kubectlCommand -ForegroundColor Green
Write-Host ""

# Run the command
Invoke-Expression $kubectlCommand

Write-Host ""