#!/usr/bin/env bash
# launch_nav2.sh  (STEP 12, HOST)  -- launch Nav2 inside the running Isaac ROS
# container. Requires cuVSLAM (map->odom) + nvblox (ESDF costmap) running.
source "$(dirname "$0")/lib/common.sh"
require_not_root
step "Nav2 -> Isaac ROS container"
docker_exec_launch "launch_nav2.sh" "$@"
