sudo  su  -

apt-get  install  debootstrap  gdisk

TARGETDEV=/dev/sdb
TARGETPART="${TARGETDEV}1"
INSTALL_PKG="ubuntu-minimal,ubuntu-standard,openssh-server,net-tools,jq,dbus-user-session"
INSTALL_COMPONENTS="main,universe,multiverse,restricted"
MOUNTPOINT="/mnt/target"
UBUNTU_MIRROR="http://nl.archive.ubuntu.com/ubuntu"

sgdisk \
  --mbrtogpt \
  --clear \
  --new 1 \
  --typecode 1:8300 \
  "${TARGETDEV}"
mkfs.ext4 "${TARGETPART}"
mkdir  --parents  "${MOUNTPOINT}"
mount  "${TARGETPART}"  "${MOUNTPOINT}"

debootstrap \
  --arch amd64 \
  --components="$INSTALL_COMPONENTS" \
  --include="$INSTALL_PKG" \
  focal "${MOUNTPOINT}"  "$UBUNTU_MIRROR"
  
mount | grep "${MOUNTPOINT}/tmp" || mount -t tmpfs tmp "${MOUNTPOINT}/tmp"
mount | grep "${MOUNTPOINT}/proc" || mount -t proc proc "${MOUNTPOINT}/proc"
mount | grep "${MOUNTPOINT}/sys" || mount -t sysfs sys "${MOUNTPOINT}/sys"
if ! mount | grep "${MOUNTPOINT}/dev"; then
    if ! mount -t devtmpfs dev "${MOUNTPOINT}/dev"; then
        mount -t tmpfs dev "${MOUNTPOINT}/dev"
        cp -a /dev/* "${MOUNTPOINT}/dev/"
        rm -rf "${MOUNTPOINT}/dev/pts"
        mkdir "${MOUNTPOINT}/dev/pts"
    fi
fi
mount | grep "${MOUNTPOINT}/dev/pts" || mount --bind /dev/pts "${MOUNTPOINT}/dev/pts"
echo "target" > "${MOUNTPOINT}/etc/debian_chroot"

wget https://www.busybox.net/downloads/binaries/1.31.0-i686-uclibc/busybox -O "${MOUNTPOINT}/busybox"
chmod +x "${MOUNTPOINT}/busybox"

DEBIAN_FRONTEND=noninteractive chroot "${MOUNTPOINT}" apt-get  --yes  install  grub-efi
chroot "${MOUNTPOINT}" grub-install "${TARGETDEV}"
chroot "${MOUNTPOINT}" update-grub

umount  "${MOUNTPOINT}/tmp"
umount  "${MOUNTPOINT}/proc"
umount  "${MOUNTPOINT}/sys"
umount  "${MOUNTPOINT}/dev/pts"
umount  "${MOUNTPOINT}/dev"
umount  "${MOUNTPOINT}"