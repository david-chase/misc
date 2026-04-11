Write-Host "Select the USB Controller to reset:" -ForegroundColor Cyan
Write-Host "1. Intel Standard Controller (80:14.0)"
Write-Host "2. Thunderbolt USB Controller (9b:00.0)"

$choice = Read-Host "Enter choice [1 or 2]"

switch ($choice) {
    "1" { 
        $target = "0000:80:14.0"
        $driver = "xhci_hcd"
    }
    "2" { 
        $target = "0000:9b:00.0"
        $driver = "xhci_hcd"
    }
    Default { 
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        return 
    }
}

Write-Host "Resetting $target using driver $driver..." -ForegroundColor Yellow

# Execute the unbind/bind sequence
echo $target | sudo tee /sys/bus/pci/drivers/$driver/unbind
Start-Sleep -Seconds 2
echo $target | sudo tee /sys/bus/pci/drivers/$driver/bind

Write-Host "Reset process complete." -ForegroundColor Green