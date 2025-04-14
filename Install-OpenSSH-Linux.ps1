Write-Host ""
Write-Host "::: Install-OpenSSH-Linux :::" -ForegroundColor Cyan
Write-Host ""

if ( $IsLinux ) {

    Write-Host "Updating package lists..." -ForegroundColor Yellow
    if ( Get-Command apt -ErrorAction SilentlyContinue ) {
        sudo apt update
    } else {
        Write-Host "apt not found. This script is designed for Debian-based systems." -ForegroundColor Red
        exit 1
    } # END if ( Get-Command apt )

    Write-Host "Installing OpenSSH server..." -ForegroundColor Yellow
    sudo apt install -y openssh-server

    Write-Host "Enabling and starting SSH service..." -ForegroundColor Yellow
    sudo systemctl enable ssh
    sudo systemctl start ssh

    $sshStatus = sudo systemctl is-active ssh
    if ( $sshStatus -eq "active" ) {
        Write-Host "SSH service is running." -ForegroundColor Green
    } else {
        Write-Host "SSH service failed to start." -ForegroundColor Red
    } # END if ( $sshStatus -eq "active" )

    Write-Host "Allowing SSH through UFW firewall (if installed)..." -ForegroundColor Yellow
    if ( Get-Command ufw -ErrorAction SilentlyContinue ) {
        sudo ufw allow ssh
        sudo ufw --force enable
        sudo ufw status verbose
    } else {
        Write-Host "ufw not installed, skipping firewall configuration." -ForegroundColor Yellow
    } # END if ( Get-Command ufw )

    Write-Host "Setting PowerShell as the default shell for current user" -ForegroundColor Yellow
    chsh -s /usr/bin/pwsh

} else {

    Write-Host "This script is intended for Linux systems only." -ForegroundColor Red

} # END if ( $IsLinux )
