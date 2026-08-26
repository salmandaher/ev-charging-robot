#!/usr/bin/env bash
# =============================================================================
#  provision_datadrive.sh  (supports STEP 3 & 5)
#  Ensures ${DATADRIVE} is a POSIX (ext4) mount suitable for Docker + Isaac ROS.
#
#  Your /media/salman/DataDrive1 is NTFS (fuseblk) -- it CANNOT host Docker
#  overlay2 or a colcon workspace. This script will NOT touch any partition
#  unless you explicitly pass a device AND type the confirmation. By default it
#  only inspects and advises.
#
#  USAGE:
#    bash provision_datadrive.sh                 # inspect + advise (safe)
#    bash provision_datadrive.sh --format /dev/sdX1   # FORMAT device ext4 -> ${DATADRIVE} (DESTRUCTIVE)
#    bash provision_datadrive.sh --bind /existing/ext4/dir  # use an existing ext4 dir as ${DATADRIVE}
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root

MODE="inspect"; TARGET=""
case "${1:-}" in
  --format) MODE="format"; TARGET="${2:-}";;
  --bind)   MODE="bind";   TARGET="${2:-}";;
  "" )      MODE="inspect";;
  *) die "Unknown arg '$1'. Use: (none) | --format /dev/sdX1 | --bind /path";;
esac

print_config

# ---- already good? ----------------------------------------------------------
if [[ -d "${DATADRIVE}" ]] && mountpoint -q "${DATADRIVE}" 2>/dev/null; then
  fstype="$(fs_type_of "${DATADRIVE}")"
  if [[ "$fstype" =~ ^(ext4|ext3|xfs|btrfs)$ ]]; then
    ok "${DATADRIVE} already mounted as ${fstype}. Nothing to do."
    df -hT "${DATADRIVE}" | sed 's/^/    /'; exit 0
  fi
fi

# ---- inspect / advise -------------------------------------------------------
if [[ "$MODE" == "inspect" ]]; then
  step "Current block devices"
  lsblk -e7 -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT,LABEL | sed 's/^/    /'
  step "Why ${DATADRIVE} is not ready"
  if [[ -e /media/salman/DataDrive1 ]]; then
    warn "/media/salman/DataDrive1 is NTFS (fuseblk). NOT usable for Docker/colcon."
  fi
  cat <<'EOF'

    You need a POSIX (ext4) filesystem with >=80 GB free. Pick ONE:

    [A] Reformat the 132 GB NTFS 'DataDrive' (nvme0n1p7) to ext4   (DESTROYS its data)
          1. Back up its contents first (to Windows C: or an external drive).
          2. sudo umount /media/salman/DataDrive1
          3. bash scripts/provision_datadrive.sh --format /dev/nvme0n1p7

    [B] External USB/Thunderbolt SSD (zero risk to existing data)
          1. Plug it in, find it:  lsblk
          2. bash scripts/provision_datadrive.sh --format /dev/sdX1

    [C] Shrink Windows/DataDrive to add a new ext4 partition (preserve data)
          - Best done from a GParted live USB; then --format the new partition.

    This script changes nothing until you pass --format <device> and confirm.
EOF
  exit 0
fi

# ---- bind an existing ext4 dir ---------------------------------------------
if [[ "$MODE" == "bind" ]]; then
  [[ -d "$TARGET" ]] || die "Bind target '$TARGET' does not exist."
  require_posix_fs "$TARGET" "DataDrive"
  ensure_sudo
  sudo mkdir -p "${DATADRIVE}"
  if mountpoint -q "${DATADRIVE}"; then ok "${DATADRIVE} already a mount."; else
    sudo mount --bind "$TARGET" "${DATADRIVE}"
    grep -q " ${DATADRIVE} " /etc/fstab || echo "${TARGET} ${DATADRIVE} none bind 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi
  ok "${DATADRIVE} now bound to ${TARGET}"; exit 0
fi

# ---- format a device to ext4 (DESTRUCTIVE) ----------------------------------
[[ -b "$TARGET" ]] || die "'$TARGET' is not a block device. Check 'lsblk'."
ensure_sudo
step "About to FORMAT ${TARGET} as ext4 -- ALL DATA ON IT WILL BE LOST"
lsblk "$TARGET" | sed 's/^/    /'
echo
read -r -p "Type EXACTLY 'FORMAT ${TARGET}' to proceed: " ans
[[ "$ans" == "FORMAT ${TARGET}" ]] || die "Confirmation mismatch. Aborted (nothing changed)."

# unmount if mounted anywhere
while mount | grep -q "^${TARGET} "; do sudo umount "$TARGET"; done
sudo mkfs.ext4 -F -L DataDrive "$TARGET"
UUID="$(sudo blkid -s UUID -o value "$TARGET")"
sudo mkdir -p "${DATADRIVE}"
# remove any stale fstab line for this mountpoint, then add a clean one
sudo sed -i "\# ${DATADRIVE} #d" /etc/fstab
echo "UUID=${UUID} ${DATADRIVE} ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab >/dev/null
sudo mount "${DATADRIVE}"
sudo chown "$USER:$USER" "${DATADRIVE}"
ok "Formatted and mounted:"
df -hT "${DATADRIVE}" | sed 's/^/    /'
require_posix_fs "${DATADRIVE}" "DataDrive"
ok "STEP 3/5 storage ready. Next: bash scripts/create_directories.sh && bash scripts/configure_docker.sh"
