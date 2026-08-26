#!/usr/bin/env bash
# =============================================================================
#  verify_network.sh  (STEP 8)  --  laptop<->Pi link + DDS multicast checks
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
source_ros
export ROS_DOMAIN_ID RMW_IMPLEMENTATION CYCLONEDDS_URI ROS_LOCALHOST_ONLY

FAILN=0
step "Interface ${ROS_IFACE}"
if ip link show "${ROS_IFACE}" >/dev/null 2>&1; then
  ip -brief addr show "${ROS_IFACE}" | sed 's/^/    /'
  [[ "$(cat /sys/class/net/${ROS_IFACE}/operstate 2>/dev/null)" == "up" ]] \
    && ok "${ROS_IFACE} is UP" || { err "${ROS_IFACE} is DOWN -- run configure_network.sh --setup-eth"; FAILN=$((FAILN+1)); }
else
  err "${ROS_IFACE} not found"; FAILN=$((FAILN+1))
fi

step "VPN / routing"
if ip route | grep -qE '(^| )0\.0\.0\.0/1 .*tun0|(^| )default .*tun0'; then
  err "VPN tun0 owns the default route -- DDS discovery will fail. Disconnect it."; FAILN=$((FAILN+1))
else
  ok "No VPN hijack of default route"
fi

step "Ping Raspberry Pi (${PI_IP})"
if ping -c 3 -W 2 "${PI_IP}" >/dev/null 2>&1; then
  ok "Pi reachable at ${PI_IP}"
else
  err "Cannot ping ${PI_IP} (check cabling/IP/PI_IP in env.sh)"; FAILN=$((FAILN+1))
fi

step "DDS multicast loopback (ros2 multicast)"
info "Starting receiver for 5s..."
timeout 6 ros2 multicast receive >/tmp/mcast_rx.txt 2>&1 &
RXPID=$!
sleep 1
ros2 multicast send >/dev/null 2>&1 || true
wait $RXPID 2>/dev/null || true
if grep -q "received" /tmp/mcast_rx.txt 2>/dev/null; then
  ok "Multicast send/receive works on this host"
else
  warn "No multicast received locally (often fine on direct links using unicast Peers)."
fi

step "Summary"
if (( FAILN > 0 )); then die "Network verification FAILED ($FAILN issue(s)). Fix before ROS bringup."; fi
ok "STEP 8 network checks passed."
