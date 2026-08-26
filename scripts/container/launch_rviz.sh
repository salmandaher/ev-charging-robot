#!/usr/bin/env bash
# launch_rviz.sh  (STEP 13, INSIDE container) -- RViz with the EV-robot config.
# Runs in-container so the nvblox_rviz_plugin (mesh display) is available.
set -Eeuo pipefail
source /workspaces/isaac_ros-dev/scripts/_env.sh
RVIZ="$(ros2 pkg prefix ev_robot_bringup)/share/ev_robot_bringup/rviz/ev_robot.rviz"
c_step "Launching RViz2 ($RVIZ)"
exec ros2 run rviz2 rviz2 -d "$RVIZ"
