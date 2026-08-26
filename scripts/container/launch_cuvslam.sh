#!/usr/bin/env bash
# launch_cuvslam.sh  (STEP 10, INSIDE container) -- start Isaac ROS Visual SLAM.
# Pass-through args, e.g.:  scripts/launch_cuvslam.sh publish_odom_to_base:=false
set -Eeuo pipefail
source /workspaces/isaac_ros-dev/scripts/_env.sh
c_step "Launching cuVSLAM (Isaac ROS Visual SLAM)"
c_warn "Needs the Pi publishing /camera/infra1|infra2/image_rect_raw + /camera/imu"
exec ros2 launch ev_robot_bringup visual_slam.launch.py "$@"
