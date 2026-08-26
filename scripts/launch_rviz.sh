#!/usr/bin/env bash
# launch_rviz.sh  (STEP 13, HOST)  -- RViz inside the container (mesh plugin),
# or fall back to host rviz2 (no nvblox mesh) with --host.
source "$(dirname "$0")/lib/common.sh"
require_not_root
if [[ "${1:-}" == "--host" ]]; then
  source_ros
  export ROS_DOMAIN_ID RMW_IMPLEMENTATION CYCLONEDDS_URI
  step "Host RViz2 (nvblox mesh display unavailable on host)"
  exec rviz2 -d "${PROJECT_DIR}/ros2_ws_src/ev_robot_bringup/rviz/ev_robot.rviz"
fi
step "RViz -> Isaac ROS container (full displays incl. nvblox mesh)"
docker_exec_launch "launch_rviz.sh"
