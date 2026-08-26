#!/usr/bin/env bash
# =============================================================================
#  verify_ros.sh  (STEP 8/9)  --  confirm ROS 2 discovery + the Pi's topics
#  Checks ros2 topic/node list and that every expected Pi topic is present.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
source_ros
export ROS_DOMAIN_ID RMW_IMPLEMENTATION CYCLONEDDS_URI ROS_LOCALHOST_ONLY

step "DDS middleware in use"
info "RMW_IMPLEMENTATION = ${RMW_IMPLEMENTATION}"
info "ROS_DOMAIN_ID      = ${ROS_DOMAIN_ID}"
info "CYCLONEDDS_URI     = ${CYCLONEDDS_URI:-<unset>}"
ros2 doctor --report 2>/dev/null | grep -iE 'middleware|RMW' | sed 's/^/    /' || true

step "Discovered nodes"
mapfile -t NODES < <(ros2 node list 2>/dev/null || true)
if (( ${#NODES[@]} )); then printf '    %s\n' "${NODES[@]}"; ok "${#NODES[@]} node(s) visible"; \
  else warn "No nodes discovered yet (is the Pi publishing? VPN off? same ROS_DOMAIN_ID=${ROS_DOMAIN_ID}?)"; fi

step "Discovered topics"
mapfile -t TOPICS < <(ros2 topic list 2>/dev/null || true)
printf '    %s\n' "${TOPICS[@]:-<none>}"

step "Checking expected topics from the Pi"
MISS=0
for t in "${PI_TOPICS[@]}"; do
  if printf '%s\n' "${TOPICS[@]}" | grep -qx "$t"; then ok "present: $t"; else err "MISSING: $t"; MISS=$((MISS+1)); fi
done

step "Camera stream sanity (rate on color image)"
if printf '%s\n' "${TOPICS[@]}" | grep -qx "/camera/color/image_raw"; then
  info "Measuring /camera/color/image_raw for 5s..."
  timeout 6 ros2 topic hz /camera/color/image_raw 2>/dev/null | grep -m1 "average rate" | sed 's/^/    /' \
    || warn "No messages on /camera/color/image_raw (topic advertised but silent)."
fi

step "Summary"
if (( MISS > 0 )); then die "${MISS} expected Pi topic(s) missing. Start the Pi camera/odom nodes and recheck."; fi
ok "STEP 8/9 complete -- all expected Pi topics present."
