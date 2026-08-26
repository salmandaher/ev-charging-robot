#!/usr/bin/env bash
# =============================================================================
#  setup_laptop.sh  --  master orchestrator (STEPS 1-7 + Isaac ROS prep)
#  Idempotent. Runs the host-side install in order, stops on failure, and skips
#  the ext4-gated steps with clear guidance until the DataDrive is provisioned.
#  Re-run it after provisioning ext4 to finish docker/dirs/isaac-ros prep.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
print_config

run() { step "RUN: $1"; bash "${SCRIPTS_DIR}/$1" "${@:2}"; }

# ---- 1. system verification (read-only) ------------------------------------
run verify_system.sh || die "Fix system issues first."

# ---- root space check ------------------------------------------------------
avail_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
if (( avail_gb < 5 )); then
  warn "Only ${avail_gb}G free on / -- running free_root_space.sh"
  run free_root_space.sh
fi

# ---- 2. Docker + NVIDIA toolkit --------------------------------------------
run install_docker.sh

# ---- 4. host ROS packages (RViz/rqt/tf/foxglove/cyclonedds) ----------------
run install_ros_packages.sh

# ---- 7. network env + CycloneDDS -------------------------------------------
run configure_network.sh

# ---- ext4 gate for the heavy Isaac ROS pieces ------------------------------
DD_FS="$(fs_type_of "${DATADRIVE}" 2>/dev/null || true)"
if [[ ! "$DD_FS" =~ ^(ext4|ext3|xfs|btrfs)$ ]]; then
  step "DataDrive not ready for Isaac ROS"
  warn "${DATADRIVE} is '${DD_FS:-absent}' -- Docker images & Isaac ROS need ext4."
  warn "Provision it, then re-run this script:"
  info "    bash ${SCRIPTS_DIR}/provision_datadrive.sh            # see options"
  info "    bash ${SCRIPTS_DIR}/provision_datadrive.sh --format /dev/nvme0n1p7   # (DESTRUCTIVE)"
  step "Host-side setup complete up to the storage gate."
  exit 0
fi

# ---- 3/5/6 storage-dependent steps -----------------------------------------
run configure_docker.sh
run create_directories.sh
run install_isaac_ros.sh

step "ALL host-side setup complete"
cat <<EOF
    Next (interactive, see docs/EXECUTION_CHECKLIST.md):
      1) bash ${SCRIPTS_DIR}/enter_container.sh          # build + enter container
      2) (in container) scripts/container_setup.sh       # deps + colcon build
      3) bash ${SCRIPTS_DIR}/launch_cuvslam.sh           # STEP 10
      4) bash ${SCRIPTS_DIR}/launch_nvblox.sh            # STEP 11
      5) bash ${SCRIPTS_DIR}/launch_nav2.sh              # STEP 12
      6) bash ${SCRIPTS_DIR}/launch_rviz.sh              # STEP 13
EOF
