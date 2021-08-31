#!/bin/bash
IFS=$'\n'
# Partly inspired on:   https://gist.github.com/superboum/1c7adcd967d3e15dfbd30d04b9ae6144#file-build-sh

[ -z "${1+x}" ] && echo "Usage $0 /dev/sdX" && exit 1

set  -o xtrace  -o errexit  -o nounset  -o pipefail  +o history

DEVICE=$1
ROOTFS="/tmp/installing-rootfs"
OS_CODENAME="focal"
OS_MIRROR="http://nl.archive.ubuntu.com/ubuntu"
KERNEL_VARIANT="generic" # other examples:  virtual, generic, aws
INSTALL_COMPONENTS="main,universe,multiverse,restricted"
INSTALL_PKG="busybox,linux-image-${KERNEL_VARIANT},linux-headers-${KERNEL_VARIANT},grub-efi"

OS_CODENAME="buster"
OS_MIRROR="http://deb.debian.org/debian"
KERNEL_VARIANT="amd64"
INSTALL_COMPONENTS="main,universe,multiverse,restricted"
INSTALL_PKG="busybox,linux-image-${KERNEL_VARIANT},linux-headers-${KERNEL_VARIANT},grub-efi"

apt-get  --yes   install  debootstrap  parted  e2fsprogs  fdisk

fdisk  --list  "${DEVICE}"
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
parted ${DEVICE} --script mkpart LINUX ext4 10MiB 100%

sleep 1

echo "Format partitions"
mkfs.vfat  -n EFI  "${DEVICE}1"
mkfs.ext4  -L LINUX  "${DEVICE}2"

echo "Mount OS partition"
mkdir  -p  "${ROOTFS}"
mount  "${DEVICE}2"  "${ROOTFS}"

echo "Debootstrap system"
debootstrap  \
  --variant=minbase \
  --arch amd64 \
  --components="${INSTALL_COMPONENTS}" \
  --include="${INSTALL_PKG}" \
  "${OS_CODENAME}" \
  "${ROOTFS}" \
  "${OS_MIRROR}"

echo "Mount EFI partition"
mkdir  --parents  "${ROOTFS}/boot/efi"
mount  "${DEVICE}1"  "${ROOTFS}/boot/efi"

echo "Get ready for chroot"
mount  --bind          /dev      "${ROOTFS}/dev"
mount  --types devpts  /dev/pts  "${ROOTFS}/dev/pts"
mount  --types proc    proc      "${ROOTFS}/proc"
mount  --types sysfs   sysfs     "${ROOTFS}/sys"
mount  --types tmpfs   tmpfs     "${ROOTFS}/tmp"

echo "Entering chroot, installing Linux kernel and Grub"
cat << EOF | chroot ${ROOTFS} /bin/bash
  set  -o xtrace  -o errexit  -o nounset  -o pipefail  +o history
  export HOME=/root
  # export DEBIAN_FRONTEND=noninteractive
  # debconf-set-selections <<< "grub-efi-amd64 grub2/update_nvram boolean false"
  # apt-get remove -y grub-efi grub-efi-amd64
  # apt-get  update
  # apt-get  install  --yes  "linux-image-${KERNEL_VARIANT}"  "linux-headers-${KERNEL_VARIANT}"  grub-efi
  # grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-nvram --removable
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${OS_CODENAME}" --recheck --no-nvram --removable
  # grub-install --target=x86_64-efi --efi-directory=/boot/efi  --bootloader-id=debian  --recheck
  # grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${OS_CODENAME}" --recheck --debug
  GRUB_DISABLE_OS_PROBER=0  update-grub
  # update-grub
  test -f /sbin/init  ||  ln  -sfnv  /bin/busybox  /sbin/init
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
