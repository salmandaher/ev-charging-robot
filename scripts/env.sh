# shellcheck shell=bash
# =============================================================================
#  env.sh  --  Central configuration for the EV-charging robot laptop stack
#  Source this (it is sourced automatically by lib/common.sh). Override any
#  value by exporting it before running a script, e.g.:
#     PI_IP=192.168.50.2 bash scripts/verify_network.sh
# =============================================================================

# ---- Storage -----------------------------------------------------------------
# DATADRIVE MUST be a POSIX filesystem (ext4/xfs). The NTFS partition at
# /media/salman/DataDrive1 is NOT valid here -- Docker overlay2 and colcon
# symlinks will fail/corrupt on it. provision_datadrive.sh enforces this.
: "${DATADRIVE:=/DataDrive}"

: "${DOCKER_DATA_ROOT:=${DATADRIVE}/docker}"
: "${ISAAC_ROS_DIR:=${DATADRIVE}/isaac_ros}"          # where NVIDIA repos are cloned
: "${WORKSPACES_DIR:=${DATADRIVE}/workspaces}"
: "${ISAAC_ROS_WS:=${WORKSPACES_DIR}/isaac_ws}"       # colcon workspace (NVIDIA convention)
: "${BAGS_DIR:=${DATADRIVE}/bags}"
: "${LOGS_DIR:=${DATADRIVE}/logs}"

# ---- ROS 2 / DDS -------------------------------------------------------------
: "${ROS_DISTRO:=humble}"
: "${ROS_DOMAIN_ID:=10}"
: "${ROS_LOCALHOST_ONLY:=0}"
: "${RMW_IMPLEMENTATION:=rmw_cyclonedds_cpp}"
: "${CYCLONEDDS_URI:=file://${PROJECT_DIR:-/home/salman/ev_charging_robot}/config/cyclonedds/cyclonedds.xml}"

# ---- Network -----------------------------------------------------------------
# Transport to the Raspberry Pi. Defaults assume a DIRECT Gigabit Ethernet link
# on a private subnet. Change ROS_IFACE/PI_IP/LAPTOP_IP to match your setup.
: "${ROS_IFACE:=eno1}"            # laptop NIC facing the Pi (eno1 = wired)
: "${LAPTOP_IP:=192.168.50.1}"    # static IP for the laptop on the robot subnet
: "${LAPTOP_CIDR:=24}"
: "${PI_IP:=192.168.50.2}"        # <-- SET THIS to your Pi's IP

# ---- Isaac ROS ---------------------------------------------------------------
# Pin the release so builds are reproducible. Bump when NVIDIA cuts a new one.
: "${ISAAC_ROS_RELEASE:=release-3.2}"
ISAAC_ROS_REPOS=(
  "isaac_ros_common"
  "isaac_ros_visual_slam"
  "isaac_ros_nvblox"
)

# ---- Robot frames (cuVSLAM / Nav2 TF tree) -----------------------------------
: "${MAP_FRAME:=map}"
: "${ODOM_FRAME:=odom}"
: "${BASE_FRAME:=base_link}"
: "${CAMERA_FRAME:=camera_link}"

# ---- Expected topics published BY the Raspberry Pi ----------------------------
PI_TOPICS=(
  "/camera/color/image_raw"
  "/camera/color/camera_info"
  "/camera/aligned_depth_to_color/image_raw"
  "/camera/aligned_depth_to_color/camera_info"
  "/camera/imu"
  "/odom"
  "/tf"
  "/tf_static"
)
# For cuVSLAM specifically you should ALSO have the Pi publish the stereo IR pair:
#   /camera/infra1/image_rect_raw  /camera/infra1/camera_info
#   /camera/infra2/image_rect_raw  /camera/infra2/camera_info
# (see docs/CAMERA_NOTES.md -- color+depth alone is not ideal for visual-inertial SLAM)
