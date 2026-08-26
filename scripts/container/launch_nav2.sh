#!/usr/bin/env bash
# launch_nav2.sh  (STEP 12, INSIDE container) -- start Navigation2.
# Requires cuVSLAM (map->odom) + nvblox (ESDF costmap) already running.
set -Eeuo pipefail
source /workspaces/isaac_ros-dev/scripts/_env.sh
c_step "Launching Nav2 (planner + RPP controller + BT, nvblox costmaps)"
c_warn "Requires cuVSLAM + nvblox running. Set a goal via RViz '2D Goal Pose'."
exec ros2 launch ev_robot_bringup nav2.launch.py "$@"
