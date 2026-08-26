#!/usr/bin/env bash
# launch_nvblox.sh  (STEP 11, INSIDE container) -- start nvblox reconstruction.
# Requires cuVSLAM running first (needs the camera pose via TF).
set -Eeuo pipefail
source /workspaces/isaac_ros-dev/scripts/_env.sh
c_step "Launching nvblox (TSDF mesh + ESDF costmap)"
c_warn "Run cuVSLAM first so map->odom->base_link->camera_link TF exists."
exec ros2 launch ev_robot_bringup nvblox.launch.py "$@"
