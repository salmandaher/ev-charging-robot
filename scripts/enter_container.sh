#!/usr/bin/env bash
# =============================================================================
#  enter_container.sh  (HOST)  --  build + enter the Isaac ROS dev container
#  Thin wrapper around NVIDIA's run_dev.sh. run_dev.sh uses --network host, so
#  DDS over eno1 works directly. Once inside, run: scripts/container_setup.sh
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
need_cmd docker || die "Docker missing. Run install_docker.sh first."

RUN_DEV="${ISAAC_ROS_WS}/src/isaac_ros_common/scripts/run_dev.sh"
[[ -f "$RUN_DEV" ]] || die "run_dev.sh not found. Run install_isaac_ros.sh first."

# keep host-synced files fresh before entering
bash "${SCRIPTS_DIR}/sync_to_workspace.sh" || warn "sync skipped"

step "Entering Isaac ROS dev container (workspace: ${ISAAC_ROS_WS})"
info "First run builds the image (long). Inside, run:"
info "    scripts/container_setup.sh           # one-time: deps + colcon build"
info "    scripts/launch_cuvslam.sh            # STEP 10"
info "    scripts/launch_nvblox.sh             # STEP 11"
info "    scripts/launch_nav2.sh               # STEP 12"
echo
cd "${ISAAC_ROS_WS}/src/isaac_ros_common"
exec ./scripts/run_dev.sh "${ISAAC_ROS_WS}"
