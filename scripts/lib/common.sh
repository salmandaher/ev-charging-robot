# shellcheck shell=bash
# =============================================================================
#  lib/common.sh  --  shared helpers: logging, guards, idempotency
#  Every script does:   source "$(dirname "$0")/lib/common.sh"
# =============================================================================

# --- strict mode (stop on failures, as required) -----------------------------
set -Eeuo pipefail

# --- locate project + load central config ------------------------------------
# lib/ lives at <PROJECT>/scripts/lib, so project root is two levels up.
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_DIR="$(cd "${_LIB_DIR}/../.." && pwd)"
export SCRIPTS_DIR="${PROJECT_DIR}/scripts"
# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/env.sh"

# --- colours (auto-disabled when not a TTY) ----------------------------------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_RED='\033[1;31m'; C_GRN='\033[1;32m'
  C_YEL='\033[1;33m'; C_BLU='\033[1;34m'; C_CYN='\033[1;36m'; C_DIM='\033[2m'
else
  C_RESET=''; C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_CYN=''; C_DIM=''
fi

step()  { printf "\n${C_BLU}==>${C_RESET} ${C_CYN}%s${C_RESET}\n" "$*"; }
info()  { printf "    %s\n" "$*"; }
ok()    { printf "    ${C_GRN}\xe2\x9c\x94${C_RESET} %s\n" "$*"; }
warn()  { printf "    ${C_YEL}\xe2\x9a\xa0${C_RESET}  %s\n" "$*" >&2; }
err()   { printf "    ${C_RED}\xe2\x9c\x98 %s${C_RESET}\n" "$*" >&2; }
die()   { err "$*"; exit 1; }

# print a clear message on ANY uncaught error, with the failing line
trap 'err "FAILED at ${BASH_SOURCE[0]}:${LINENO} (exit $?). Stopping."' ERR

# --- guards ------------------------------------------------------------------
need_cmd()    { command -v "$1" >/dev/null 2>&1; }
require_cmd() { need_cmd "$1" || die "Required command not found: $1  ($2)"; }

require_not_root() {
  [[ "${EUID}" -ne 0 ]] || die "Do NOT run this as root/sudo. Run as user '$USER'; it will sudo only where needed."
}

# Ask once for the sudo password and keep it warm (so long installs don't stall).
ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    warn "This step needs sudo. Enter your password once:"
    sudo -v || die "sudo authentication failed."
  fi
  # refresh the timestamp in the background until this script exits
  ( while true; do sudo -n true 2>/dev/null; sleep 50; done ) &
  _SUDO_KEEPALIVE_PID=$!
  trap '[[ -n "${_SUDO_KEEPALIVE_PID:-}" ]] && kill "${_SUDO_KEEPALIVE_PID}" 2>/dev/null || true' EXIT
}

confirm() {  # confirm "message"  -> returns 0 if yes
  local reply
  printf "${C_YEL}?${C_RESET} %s [y/N] " "$*"
  read -r reply || true
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# --- filesystem safety: refuse NTSF/FUSE/vfat for Docker & colcon ------------
fs_type_of() { df -PT "$1" 2>/dev/null | awk 'NR==2{print $2}'; }

require_posix_fs() {  # require_posix_fs <path> <purpose>
  local path="$1" purpose="${2:-this}"
  local mountpoint; mountpoint="$(df -P "$path" 2>/dev/null | awk 'NR==2{print $6}')"
  [[ -n "$mountpoint" ]] || die "Path '$path' is not on any mounted filesystem yet."
  local fstype; fstype="$(fs_type_of "$path")"
  case "$fstype" in
    ext4|ext3|xfs|btrfs)
      ok "$path is on ${fstype} (valid for ${purpose})" ;;
    fuseblk|ntfs|ntfs3|vfat|exfat|"")
      err "$path is on '${fstype:-unknown}' (mount: ${mountpoint})."
      err "Docker overlay2 and colcon symlinks CANNOT run on NTFS/FUSE/FAT."
      die  "Provision an ext4 mount first:  bash scripts/provision_datadrive.sh"
      ;;
    *)
      warn "$path is on '${fstype}' -- unusual for ${purpose}; proceeding with caution." ;;
  esac
}

# idempotent mkdir owned by the invoking user
mkdir_user() { for d in "$@"; do [[ -d "$d" ]] || mkdir -p "$d"; done; }

# is an apt package installed?
apt_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }

# source ROS if available
source_ros() {
  [[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]] || die "ROS ${ROS_DISTRO} not found at /opt/ros/${ROS_DISTRO}"
  # shellcheck source=/dev/null
  source "/opt/ros/${ROS_DISTRO}/setup.bash"
}

# --- Isaac ROS container helpers ---------------------------------------------
isaac_container() {  # echo name of the running Isaac ROS dev container, if any
  docker ps --filter "name=isaac_ros_dev" --format '{{.Names}}' 2>/dev/null | head -1
}

# run an in-container launch script via docker exec; $1=script name, $2..=args
docker_exec_launch() {
  local script="$1"; shift
  local c; c="$(isaac_container)"
  [[ -n "$c" ]] || die "No running Isaac ROS container found.
    Open another terminal and run:  bash ${SCRIPTS_DIR}/enter_container.sh
    (leave it running, then re-run this script)."
  ok "Using container: $c"
  exec docker exec -it "$c" bash -lc "/workspaces/isaac_ros-dev/scripts/${script} $*"
}

print_config() {
  step "Active configuration"
  info "DATADRIVE        = ${DATADRIVE}"
  info "DOCKER_DATA_ROOT = ${DOCKER_DATA_ROOT}"
  info "ISAAC_ROS_DIR    = ${ISAAC_ROS_DIR}"
  info "ISAAC_ROS_WS     = ${ISAAC_ROS_WS}"
  info "ROS_DOMAIN_ID    = ${ROS_DOMAIN_ID}    RMW = ${RMW_IMPLEMENTATION}"
  info "ROS_IFACE/PI_IP  = ${ROS_IFACE}  ->  ${PI_IP}"
}
