#!/usr/bin/env bash
# =============================================================================
#  verify_navigation.sh  --  end-to-end checks for the perception+nav stack
#  Run on the HOST (topics are shared over DDS). Verifies TF chain, cuVSLAM
#  odometry, nvblox outputs, costmaps, and Nav2 lifecycle state.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
source_ros
export ROS_DOMAIN_ID RMW_IMPLEMENTATION CYCLONEDDS_URI ROS_LOCALHOST_ONLY

have_topic(){ ros2 topic list 2>/dev/null | grep -qx "$1"; }
check_topic(){ if have_topic "$1"; then ok "topic: $1"; else err "missing topic: $1"; FAILN=$((FAILN+1)); fi; }
FAILN=0

step "TF tree (expect map -> odom -> base_link -> camera_link)"
for pair in "${MAP_FRAME}:${ODOM_FRAME}" "${ODOM_FRAME}:${BASE_FRAME}" "${BASE_FRAME}:${CAMERA_FRAME}"; do
  p="${pair%%:*}"; c="${pair##*:}"
  if timeout 5 ros2 run tf2_ros tf2_echo "$p" "$c" >/dev/null 2>&1; then ok "TF $p -> $c OK"; \
    else err "TF $p -> $c MISSING"; FAILN=$((FAILN+1)); fi
done

step "cuVSLAM (STEP 10)"
check_topic /visual_slam/tracking/odometry
if have_topic /visual_slam/tracking/odometry; then
  timeout 6 ros2 topic hz /visual_slam/tracking/odometry 2>/dev/null | grep -m1 "average rate" | sed 's/^/    /' || warn "no odometry msgs yet"
fi

step "nvblox (STEP 11)"
check_topic /nvblox_node/mesh
check_topic /nvblox_node/map_slice

step "Nav2 costmaps + planning (STEP 12)"
check_topic /global_costmap/costmap
check_topic /local_costmap/costmap

step "Nav2 lifecycle nodes"
for n in /controller_server /planner_server /bt_navigator /behavior_server; do
  if ros2 node list 2>/dev/null | grep -qx "$n"; then
    state="$(timeout 4 ros2 lifecycle get "$n" 2>/dev/null || echo unknown)"
    [[ "$state" == *active* ]] && ok "$n: $state" || { warn "$n: $state"; }
  else err "$n not found"; FAILN=$((FAILN+1)); fi
done

step "Summary"
if (( FAILN > 0 )); then die "Navigation verification: ${FAILN} problem(s). See red items."; fi
ok "Navigation stack verified. Send a goal:  RViz '2D Goal Pose'  or  ros2 topic pub /goal_pose ..."
