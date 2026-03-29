# Configuration
$BackupDir = "/mnt/nfs/etcd-backups"
$EtcdDataDir = "/var/lib/etcd"
$ManifestDir = "/etc/kubernetes/manifests"
$TempManifestDir = "/etc/kubernetes/manifests-temp"

# 1. List available snapshots
if (-not (Test-Path $BackupDir)) {
    Write-Host "Error: Backup directory $BackupDir not found." -ForegroundColor Red
    exit 1
}

$Snapshots = Get-ChildItem -Path $BackupDir -Filter "*.db" | Sort-Object LastWriteTime -Descending

if ($Snapshots.Count -eq 0) {
    Write-Host "No snapshots found in $BackupDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "Available etcd snapshots (Newest first):" -ForegroundColor Cyan
for ($i = 0; $i -lt $Snapshots.Count; $i++) {
    Write-Host "[$i] $($Snapshots[$i].Name) ($($Snapshots[$i].LastWriteTime))"
}

$Selection = Read-Host "Select the index of the snapshot to restore"
if ($Selection -lt 0 -or $Selection -ge $Snapshots.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    exit 1
}

$SelectedSnapshot = $Snapshots[$Selection].FullName
Write-Host "Selected: $SelectedSnapshot" -ForegroundColor Magenta

# 2. Confirm Restoration
$Confirm = Read-Host "This will STOP the control plane and DELETE current etcd data. Proceed? (y/n)"
if ($Confirm -ne "y") { exit 0 }

# 3. Stop Kubernetes Control Plane
Write-Host "Moving manifests to stop API Server and etcd..." -ForegroundColor Yellow
if (-not (Test-Path $TempManifestDir)) { sudo mkdir -p $TempManifestDir }
sudo mv "$ManifestDir/kube-apiserver.yaml" "$TempManifestDir/"
sudo mv "$ManifestDir/etcd.yaml" "$TempManifestDir/"

# Wait for containers to stop
Start-Sleep -Seconds 10

# 4. Backup and Clear existing etcd data
Write-Host "Clearing existing etcd data at $EtcdDataDir..." -ForegroundColor Yellow
sudo mv $EtcdDataDir "${EtcdDataDir}.old-$(Get-Date -Format 'yyyyMMdd')"

# 5. Perform Restore
Write-Host "Restoring snapshot..." -ForegroundColor Cyan
sudo ETCDCTL_API=3 etcdctl `
    --endpoints=https://127.0.0.1:2379 `
    --cacert=/etc/kubernetes/pki/etcd/ca.crt `
    --cert=/etc/kubernetes/pki/etcd/server.crt `
    --key=/etc/kubernetes/pki/etcd/server.key `
    --data-dir=$EtcdDataDir `
    snapshot restore $SelectedSnapshot

# 6. Fix permissions on restored data
sudo chown -R 0:0 $EtcdDataDir

# 7. Restart Control Plane
Write-Host "Moving manifests back to start services..." -ForegroundColor Green
sudo mv "$TempManifestDir/etcd.yaml" "$ManifestDir/"
sudo mv "$TempManifestDir/kube-apiserver.yaml" "$ManifestDir/"

Write-Host "Restore complete. It may take 1-2 minutes for the API server to become responsive." -ForegroundColor Green
