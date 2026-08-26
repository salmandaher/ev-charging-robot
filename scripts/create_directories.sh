#!/usr/bin/env bash
# =============================================================================
#  create_directories.sh  (STEP 5)  --  create the DataDrive directory layout
#  All large data lives on the ext4 DataDrive (never NTFS, never ~).
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root

print_config
step "Validating DataDrive is a real POSIX filesystem"
[[ -d "${DATADRIVE}" ]] || die "${DATADRIVE} does not exist. Run provision_datadrive.sh first."
require_posix_fs "${DATADRIVE}" "Isaac ROS data"

# create + ensure user ownership
DIRS=(
  "${ISAAC_ROS_DIR}"
  "${WORKSPACES_DIR}"
  "${ISAAC_ROS_WS}"
  "${ISAAC_ROS_WS}/src"
  "${BAGS_DIR}"
  "${LOGS_DIR}"
)
step "Creating directories"
for d in "${DIRS[@]}"; do
  if [[ -d "$d" ]]; then ok "exists: $d"; else
    if mkdir -p "$d" 2>/dev/null; then ok "created: $d"; else
      sudo mkdir -p "$d"; sudo chown "$USER:$USER" "$d"; ok "created (sudo): $d"; fi
  fi
done

step "STEP 5 complete -- layout:"
find "${DATADRIVE}" -maxdepth 2 -type d 2>/dev/null | sort | sed 's/^/    /'
