Write-Host ""
Write-Host "::: Connect-to-NFS-Share :::" -ForegroundColor Cyan
Write-Host ""

Write-Host Installing NFS client -ForegroundColor Green
sudo apt update
sudo apt install -y nfs-common

Write-Host Creating mount point -ForegroundColor Green
sudo mkdir -p /mnt/nfs

Write-Host Mounting NFS share -ForegroundColor Green
sudo echo "192.168.1.100:/srv/nfs  /mnt/nfs  nfs  defaults  0  0" >> /etc/fstab
sudo mount -a