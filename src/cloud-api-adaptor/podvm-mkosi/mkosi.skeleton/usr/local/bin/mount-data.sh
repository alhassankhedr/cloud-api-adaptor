#!/usr/bin/env bash
set -euxo pipefail

# Find the scratch partition by label (trusted_store) or fallback to sda4
# With squashfs root, partition layout is:
# sda1: ESP, sda2: Root (squashfs, read-only), sda3: Verity hash, sda4: Scratch (writable)
DEVICE=""
MAX_WAIT=30
WAITED=0

# Try to find by label first
if [ -L "/dev/disk/by-label/trusted_store" ]; then
    DEVICE=$(readlink -f /dev/disk/by-label/trusted_store)
    echo "Found scratch partition by label: $DEVICE"
elif [ -b "/dev/sda4" ]; then
    DEVICE="/dev/sda4"
    echo "Using sda4 as scratch partition"
else
    # Find the largest ext4 partition that's not root, ESP, or verity
    ROOT_DISK="sda"
    DEVICE=$(lsblk -n -o NAME,TYPE,SIZE | awk '$2=="part"{name=$1; gsub(/^[│├└─ ]+/, "", name); if (name !~ /^\/dev\//) name="/dev/" name; print name,$3}' | while read -r p size; do
        d=$(lsblk -no PKNAME "$p" 2>/dev/null || echo)
        if [ "$d" = "$ROOT_DISK" ] && [ "$p" != "/dev/sda1" ] && [ "$p" != "/dev/sda2" ] && [ "$p" != "/dev/sda3" ]; then
            fs=$(blkid -o value -s TYPE "$p" 2>/dev/null || echo "")
            if [ "$fs" = "ext4" ] || [ -z "$fs" ]; then
                echo "$p $size"
            fi
        fi
    done | sort -k2 -rn | head -n 1 | awk '{print $1}')
    
    if [ -z "$DEVICE" ]; then
        echo "ERROR: Could not find scratch/data partition"
        exit 1
    fi
    echo "Found data partition: $DEVICE"
fi

# Wait for device to appear
while [ ! -b "$DEVICE" ] && [ $WAITED -lt $MAX_WAIT ]; do
    echo "Waiting for $DEVICE to appear... ($WAITED/$MAX_WAIT seconds)"
    sleep 1
    WAITED=$((WAITED + 1))
done

if [ ! -b "$DEVICE" ]; then
    echo "ERROR: $DEVICE did not appear within $MAX_WAIT seconds"
    exit 1
fi

echo "$DEVICE is available"

# Format as ext4 only if it has no filesystem
if ! blkid "$DEVICE" >/dev/null 2>&1; then
    echo "Formatting $DEVICE with ext4..."
    mkfs.ext4 -F "$DEVICE"
else
    echo "$DEVICE already has a filesystem: $(blkid -o value -s TYPE "$DEVICE")"
fi

# Mount point - use /run/mounts/data since root is read-only (squashfs)
MOUNT_POINT="/run/mounts/data"
mkdir -p "$MOUNT_POINT"

# Mount the device if not already mounted
if ! mountpoint -q "$MOUNT_POINT"; then
    mount "$DEVICE" "$MOUNT_POINT"
    echo "Mounted $DEVICE to $MOUNT_POINT"
else
    echo "$MOUNT_POINT is already mounted"
fi

# Resize filesystem if partition was expanded by systemd-repart
# Check if filesystem is ext4 and if partition size > filesystem size
FS_TYPE=$(blkid -o value -s TYPE "$DEVICE" 2>/dev/null || echo "")
if [ "$FS_TYPE" = "ext4" ] && command -v resize2fs >/dev/null 2>&1; then
    # Get partition size in bytes
    PART_SIZE=$(blockdev --getsize64 "$DEVICE" 2>/dev/null || echo "0")
    # Get filesystem size in bytes (from df)
    FS_SIZE=$(df -B1 "$MOUNT_POINT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "0")
    
    if [ "$PART_SIZE" != "0" ] && [ "$FS_SIZE" != "0" ] && [ "$PART_SIZE" -gt "$FS_SIZE" ]; then
        # Check if partition is significantly larger than filesystem (>10% difference)
        DIFF=$((PART_SIZE - FS_SIZE))
        DIFF_PERCENT=$((DIFF * 100 / PART_SIZE))
        if [ $DIFF_PERCENT -gt 10 ]; then
            echo "Partition expanded by systemd-repart, resizing filesystem..."
            if command -v numfmt >/dev/null 2>&1; then
                echo "  Partition size: $(numfmt --to=iec-i --suffix=B $PART_SIZE)"
                echo "  Filesystem size: $(numfmt --to=iec-i --suffix=B $FS_SIZE)"
            else
                echo "  Partition size: $PART_SIZE bytes"
                echo "  Filesystem size: $FS_SIZE bytes"
            fi
            if resize2fs "$DEVICE" 2>&1; then
                echo "Filesystem resize complete"
            else
                echo "Warning: Failed to resize filesystem (non-fatal)"
            fi
        fi
    fi
fi

# Create directories for bind mounts
mkdir -p "$MOUNT_POINT/kubelet"
mkdir -p "$MOUNT_POINT/containerd"

# Bind-mount /run/mounts/data/kubelet → /var/lib/kubelet
KUBELET_TARGET="/var/lib/kubelet"
if [ -d "$KUBELET_TARGET" ] && [ "$(ls -A "$KUBELET_TARGET" 2>/dev/null)" ]; then
    echo "Copying existing content from $KUBELET_TARGET to $MOUNT_POINT/kubelet..."
    rsync -aHAX "$KUBELET_TARGET"/ "$MOUNT_POINT/kubelet"/ 2>/dev/null || true
fi
mkdir -p "$KUBELET_TARGET"
if ! mountpoint -q "$KUBELET_TARGET"; then
    mount --bind "$MOUNT_POINT/kubelet" "$KUBELET_TARGET"
    echo "Bind-mounted $MOUNT_POINT/kubelet to $KUBELET_TARGET"
else
    echo "$KUBELET_TARGET is already mounted"
fi

# Bind-mount /run/mounts/data/containerd → /var/lib/containerd
CONTAINERD_TARGET="/var/lib/containerd"
if [ -d "$CONTAINERD_TARGET" ] && [ "$(ls -A "$CONTAINERD_TARGET" 2>/dev/null)" ]; then
    echo "Copying existing content from $CONTAINERD_TARGET to $MOUNT_POINT/containerd..."
    rsync -aHAX "$CONTAINERD_TARGET"/ "$MOUNT_POINT/containerd"/ 2>/dev/null || true
fi
mkdir -p "$CONTAINERD_TARGET"
if ! mountpoint -q "$CONTAINERD_TARGET"; then
    mount --bind "$MOUNT_POINT/containerd" "$CONTAINERD_TARGET"
    echo "Bind-mounted $MOUNT_POINT/containerd to $CONTAINERD_TARGET"
else
    echo "$CONTAINERD_TARGET is already mounted"
fi

echo "Data mount setup complete. Kubernetes storage is now on $DEVICE"
