#!/usr/bin/env bash
# launch_cuvslam.sh  (STEP 10, HOST)  -- launch cuVSLAM inside the running
# Isaac ROS container. Start the container first: bash scripts/enter_container.sh
source "$(dirname "$0")/lib/common.sh"
require_not_root
step "cuVSLAM -> Isaac ROS container"
docker_exec_launch "launch_cuvslam.sh" "$@"
