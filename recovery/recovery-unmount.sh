#!/bin/bash
set -e

self_path=$(dirname "$(readlink -e "$0")")

if test "$1" != "--yes"; then
    cat <<EOF
Usage: $0 --yes
EOF
    exit 1
fi
shift

. "$self_path/bootstrap-library.sh"

if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
    echo "error: looks like we are inside a chroot, refusing to continue as safety measure. try 'exit' to exit from the chroot first."
    exit 1
fi

cd /
echo "swap off"; swapoff -a || true
unmount_bind_mounts /mnt
unmount_data /mnt/mnt
unmount_efi /mnt
unmount_boot /mnt
unmount_root /mnt
deactivate_lvm
deactivate_crypt
deactivate_raid

echo "unmounted everything, it should be safe now to reboot"
