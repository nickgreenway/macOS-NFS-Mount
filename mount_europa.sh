#!/bin/bash

# Mount point
MOUNT_POINT="/Volumes/Europa"
NFS_SERVER="10.0.0.4:/volume1/Europa"

# Check if the mount point exists; create it if not
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted; if not, mount the NFS share
if ! mount | grep -q "$MOUNT_POINT"; then
    mount -t nfs -o rw,hard,intr,proto=tcp,rsize=65536,wsize=65536,nfsvers=4 "$NFS_SERVER" "$MOUNT_POINT"
fi
