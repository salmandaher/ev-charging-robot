# shellcheck shell=bash
# Sourced by the in-container launch scripts. Sets ROS + DDS env so the laptop
# container talks to the Pi on the same domain/middleware. Edit to match env.sh.
WS=/workspaces/isaac_ros-dev
source /opt/ros/humble/setup.bash
[ -f "${WS}/install/setup.bash" ] && source "${WS}/install/setup.bash"

export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-10}
export ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-0}
export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}
[ -f "${WS}/cyclonedds.xml" ] && export CYCLONEDDS_URI="file://${WS}/cyclonedds.xml"

c_step(){ printf "\n\033[1;34m==>\033[0m \033[1;36m%s\033[0m\n" "$*"; }
c_ok(){   printf "    \033[1;32m\xe2\x9c\x94\033[0m %s\n" "$*"; }
c_warn(){ printf "    \033[1;33m\xe2\x9a\xa0\033[0m  %s\n" "$*"; }
