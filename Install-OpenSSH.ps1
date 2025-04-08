
Write-Host ""  # Blank line before header
Write-Host "::: InstallOpenSSH.ps1 :::" -ForegroundColor Cyan
Write-Host ""  # Blank line after header

# Check for Administrator privileges
$IsAdmin = ( [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )

if ( -not $IsAdmin ) {
    Write-Host "This script must be run as Administrator. Exiting..." -ForegroundColor Red
    exit 1
} # END if ( -not $IsAdmin )

# Try to install OpenSSH Client
try {
    Write-Host "Installing OpenSSH Client (will skip if already installed)..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0"
} catch {
    Write-Host "Failed to install OpenSSH Client. Error: $_" -ForegroundColor Red
    exit 2
} # END catch

# Try to install OpenSSH Server
try {
    Write-Host "Installing OpenSSH Server (will skip if already installed)..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
} catch {
    Write-Host "Failed to install OpenSSH Server. Error: $_" -ForegroundColor Red
    exit 3
} # END catch

# Enable and start ssh-agent
Write-Host "Enabling and starting ssh-agent..." -ForegroundColor Yellow
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service -Name ssh-agent

# Enable and start sshd (OpenSSH Server)
Write-Host "Enabling and starting sshd..." -ForegroundColor Yellow
Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

Write-Host "`nOpenSSH installation and setup complete." -ForegroundColor Cyan
