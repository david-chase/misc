    #!/usr/bin/env bash
    
    sudo cryptsetup open /dev/sdb1 data
    sudo cryptsetup open /dev/sda1 data_backup
    sudo mount -a