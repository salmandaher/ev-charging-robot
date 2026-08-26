#!/usr/bin/env bash
# =============================================================================
#  sync_to_workspace.sh  --  copy bringup package + DDS config + in-container
#  scripts into ${ISAAC_ROS_WS} so they are visible inside the Isaac ROS
#  container (which mounts ISAAC_ROS_WS at /workspaces/isaac_ros-dev).
#  Run on the HOST whenever you change launch files / params.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
[[ -d "${ISAAC_ROS_WS}" ]] || die "${ISAAC_ROS_WS} missing. Run create_directories.sh / install_isaac_ros.sh first."
require_posix_fs "${ISAAC_ROS_WS}" "workspace"

step "Syncing ev_robot_bringup -> ${ISAAC_ROS_WS}/src"
mkdir_user "${ISAAC_ROS_WS}/src"
rsync -a --delete "${PROJECT_DIR}/ros2_ws_src/ev_robot_bringup" "${ISAAC_ROS_WS}/src/"
ok "package synced"

step "Placing DDS config + in-container scripts in workspace root"
cp -f "${PROJECT_DIR}/config/cyclonedds/cyclonedds.xml" "${ISAAC_ROS_WS}/cyclonedds.xml"
mkdir_user "${ISAAC_ROS_WS}/scripts"
cp -f "${PROJECT_DIR}/scripts/container/"*.sh "${ISAAC_ROS_WS}/scripts/"
chmod +x "${ISAAC_ROS_WS}/scripts/"*.sh 2>/dev/null || true
ok "cyclonedds.xml + container scripts copied to ${ISAAC_ROS_WS}"

step "Done"
info "Inside the container these appear at:"
info "  /workspaces/isaac_ros-dev/src/ev_robot_bringup"
info "  /workspaces/isaac_ros-dev/cyclonedds.xml"
info "  /workspaces/isaac_ros-dev/scripts/*.sh"
