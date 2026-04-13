# Define snapshot directory and file naming
$SnapshotDir = "/mnt/nfs/etcd-snapshots"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$SnapshotPath = "$SnapshotDir/snapshot-$Timestamp.db"

# Ensure the directory exists
if (-not (Test-Path $SnapshotDir)) {
    New-Item -ItemType Directory -Path $SnapshotDir | Out-Null
}

# Define etcd authentication parameters (Standard kubeadm paths)
$Endpoints = "https://127.0.0.1:2379"
$CA = "/etc/kubernetes/pki/etcd/ca.crt"
$Cert = "/etc/kubernetes/pki/etcd/server.crt"
$Key = "/etc/kubernetes/pki/etcd/server.key"

# Capture the snapshot
Write-Host "Starting etcd snapshot: $SnapshotPath"
sudo ETCDCTL_API=3 etcdctl snapshot save $SnapshotPath `
    --endpoints=$Endpoints `
    --cacert=$CA `
    --cert=$Cert `
    --key=$Key

# Verify if snapshot was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Snapshot captured successfully." -ForegroundColor Green
} else {
    Write-Error "Failed to capture etcd snapshot."
    exit 1
}

# Cleanup: Keep only the 30 most recent snapshots
$MaxSnapshots = 10
$OldSnapshots = Get-ChildItem -Path $SnapshotDir -Filter "snapshot-*.db" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -Skip $MaxSnapshots

if ($OldSnapshots) {
    Write-Host "Cleaning up $($OldSnapshots.Count) old snapshots..."
    $OldSnapshots | Remove-Item -Force
}
