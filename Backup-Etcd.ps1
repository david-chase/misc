# Define the backup directory and filename
$BackupDir = "/mnt/nfs/etcd-backups"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$Filename = "snapshot-$Timestamp.db"
$FullDestination = Join-Path $BackupDir $Filename

# Ensure the backup directory exists
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

Write-Host "Starting etcd snapshot: $FullDestination" -ForegroundColor Cyan

# Execute etcdctl via sudo
# Note: kubeadm default paths for certs are used here
sudo ETCDCTL_API=3 etcdctl `
    --endpoints=https://127.0.0.1:2379 `
    --cacert=/etc/kubernetes/pki/etcd/ca.crt `
    --cert=/etc/kubernetes/pki/etcd/server.crt `
    --key=/etc/kubernetes/pki/etcd/server.key `
    snapshot save $FullDestination

if ($LASTEXITCODE -eq 0) {
    Write-Host "Snapshot successfully created at $FullDestination" -ForegroundColor Green
    
    # Verify the snapshot status
    sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status $FullDestination
}
else {
    Write-Host "Error: Failed to create etcd snapshot." -ForegroundColor Red
    exit 1
}