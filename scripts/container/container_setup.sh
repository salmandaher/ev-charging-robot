#!/usr/bin/env bash
# =============================================================================
#  container_setup.sh  (INSIDE the Isaac ROS container)  --  one-time setup
#  Installs cuVSLAM + nvblox + RealSense + cyclonedds RMW, then builds the ws.
# =============================================================================
set -Eeuo pipefail
WS=/workspaces/isaac_ros-dev
cd "$WS"
source "$WS/scripts/_env.sh" 2>/dev/null || source /opt/ros/humble/setup.bash

c_step "Installing Isaac ROS packages + cyclonedds RMW (apt)"
sudo apt-get update
sudo apt-get install -y \
  ros-humble-isaac-ros-visual-slam \
  ros-humble-isaac-ros-nvblox \
  ros-humble-isaac-ros-examples \
  ros-humble-isaac-ros-realsense \
  ros-humble-nvblox-rviz-plugin \
  ros-humble-rmw-cyclonedds-cpp \
  ros-humble-robot-localization \
  ros-humble-navigation2 ros-humble-nav2-bringup \
  ros-humble-nav2-regulated-pure-pursuit-controller \
  ros-humble-nav2-smac-planner || c_warn "Some apt packages may already be present / named differently in your release."

c_step "rosdep for the workspace sources"
sudo apt-get update
rosdep update || true
rosdep install -i -r -y --from-paths src --rosdistro humble || c_warn "rosdep had non-fatal misses"

c_step "Building the workspace (limited parallelism for 15GB RAM)"
colcon build --symlink-install --parallel-workers 6 \
  --cmake-args -DCMAKE_BUILD_TYPE=Release
source install/setup.bash

c_step "Verifying packages are visible"
ros2 pkg list | grep -E "isaac_ros_visual_slam|nvblox|ev_robot_bringup" || true
c_ok "container setup complete. Now: scripts/launch_cuvslam.sh"
