#!/usr/bin/env bash
# launch_nvblox.sh  (STEP 11, HOST)  -- launch nvblox inside the running
# Isaac ROS container. Requires cuVSLAM already running.
source "$(dirname "$0")/lib/common.sh"
require_not_root
step "nvblox -> Isaac ROS container"
docker_exec_launch "launch_nvblox.sh" "$@"
