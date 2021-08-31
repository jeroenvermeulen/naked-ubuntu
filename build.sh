#!/bin/bash
IFS=$'\n'
set  -o xtrace  -o errexit  -o nounset  -o pipefail  +o history

# Inspired on:   https://gist.github.com/superboum/1c7adcd967d3e15dfbd30d04b9ae6144#file-build-sh

DEVICE=$1
[ -z "${DEVICE}" ] && echo "Usage $0 /dev/sdX" && exit 1

udevadm info -n ${DEVICE} -q property
echo "Selected device is ${DEVICE}"
read -p "[Press enter to continue or CTRL+C to stop]"

echo "Umount ${DEVICE}"
umount ${DEVICE}* || true

echo "Set partition table to GPT (UEFI)"
parted ${DEVICE} --script mktable gpt

echo "Create EFI partition"
parted ${DEVICE} --script mkpart EFI fat16 1MiB 10MiB
parted ${DEVICE} --script set 1 msftdata on

echo "Create OS partition"
parted ${DEVICE} --script mkpart LINUX btrfs 10MiB 100%

echo "Format partitions"
mkfs.vfat -n EFI ${DEVICE}1
mkfs.btrfs -f -L LINUX ${DEVICE}2

echo "Mount OS partition"
ROOTFS="/tmp/installing-rootfs"
mkdir -p ${ROOTFS}
mount ${DEVICE}2 ${ROOTFS}

echo "Debootstrap system"
debootstrap --variant=minbase --arch amd64 buster ${ROOTFS} http://deb.debian.org/debian/

echo "Mount EFI partition"
mkdir -p ${ROOTFS}/boot/efi
mount ${DEVICE}1 ${ROOTFS}/boot/efi

echo "Get ready for chroot"
mount --bind /dev ${ROOTFS}/dev
mount -t devpts /dev/pts ${ROOTFS}/dev/pts
mount -t proc proc ${ROOTFS}/proc
mount -t sysfs sysfs ${ROOTFS}/sys
mount -t tmpfs tmpfs ${ROOTFS}/tmp

echo "Entering chroot, installing Linux kernel and Grub"
cat << EOF | chroot ${ROOTFS}
  set -e
  export HOME=/root
  export DEBIAN_FRONTEND=noninteractive
  debconf-set-selections <<< "grub-efi-amd64 grub2/update_nvram boolean false"
  apt-get remove -y grub-efi grub-efi-amd64
  apt-get update
  apt-get install -y linux-image-amd64 linux-headers-amd64 grub-efi
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-nvram --removable
  update-grub
EOF


echo "Unmounting filesystems"
umount ${ROOTFS}/dev/pts
umount ${ROOTFS}/dev
umount ${ROOTFS}/proc
umount ${ROOTFS}/sys
umount ${ROOTFS}/tmp
umount ${ROOTFS}/boot/efi
umount ${ROOTFS}

echo "Done"
