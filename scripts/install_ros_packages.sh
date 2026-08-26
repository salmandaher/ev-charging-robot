#!/usr/bin/env bash
# =============================================================================
#  install_ros_packages.sh  (STEP 4)  --  host ROS 2 Humble packages
#  Idempotent: only installs what is missing. Installs to /usr (root fs).
#
#  NOTE: Perception (cuVSLAM, nvblox, Nav2) ultimately runs INSIDE the Isaac ROS
#  container. These HOST packages are for tooling you run on the laptop directly
#  (RViz, rqt, tf tools, foxglove, cyclonedds RMW, bag plugins).
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
[[ -f /opt/ros/${ROS_DISTRO}/setup.bash ]] || die "ROS ${ROS_DISTRO} not installed."
ensure_sudo

PKGS=(
  ros-humble-navigation2
  ros-humble-nav2-bringup
  ros-humble-robot-localization
  ros-humble-image-transport
  ros-humble-image-transport-plugins
  ros-humble-rviz2
  ros-humble-rqt-graph
  ros-humble-rqt-tf-tree
  ros-humble-tf2-tools
  ros-humble-diagnostic-updater
  ros-humble-diagnostics
  ros-humble-foxglove-bridge
  ros-humble-cyclonedds
  ros-humble-rmw-cyclonedds-cpp          # REQUIRED for RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  ros-humble-rosbag2-storage-default-plugins
)

step "Checking which packages are already installed"
TO_INSTALL=()
for p in "${PKGS[@]}"; do
  if apt_installed "$p"; then ok "present: $p"; else info "missing: $p"; TO_INSTALL+=("$p"); fi
done

if (( ${#TO_INSTALL[@]} == 0 )); then
  ok "All ${#PKGS[@]} packages already installed. Nothing to do."
else
  step "Installing ${#TO_INSTALL[@]} package(s)"
  avail_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
  (( avail_gb >= 3 )) || warn "Only ${avail_gb}G free on / -- install may fail. Run scripts/free_root_space.sh first."
  sudo apt-get update -qq
  sudo apt-get install -y "${TO_INSTALL[@]}"
fi

step "Verifying key binaries / packages"
for p in "${PKGS[@]}"; do apt_installed "$p" || die "Package failed to install: $p"; done
ok "All host ROS packages installed."

# sanity: cyclonedds RMW loadable
source_ros
if RMW_IMPLEMENTATION=rmw_cyclonedds_cpp ros2 doctor --report >/dev/null 2>&1; then
  ok "rmw_cyclonedds_cpp loads correctly"
else
  warn "Could not confirm rmw_cyclonedds_cpp via ros2 doctor (non-fatal)."
fi
step "STEP 4 complete"
