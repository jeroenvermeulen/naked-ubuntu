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