#!/usr/bin/env bash
# =============================================================================
#  verify_system.sh  (STEP 1)  --  read-only system verification
#  Confirms: Ubuntu 22.04, ROS2 Humble, NVIDIA driver, GPU, CUDA, Docker,
#  Ethernet, and usable storage. Prints a PASS/FAIL summary. No sudo, no changes.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root

PASS=0; FAILN=0; WARNN=0
check()  { if eval "$2" >/dev/null 2>&1; then ok "$1"; PASS=$((PASS+1)); else err "$1"; FAILN=$((FAILN+1)); fi; }
softck() { if eval "$2" >/dev/null 2>&1; then ok "$1"; PASS=$((PASS+1)); else warn "$1"; WARNN=$((WARNN+1)); fi; }

step "OS / Distribution"
. /etc/os-release
info "$PRETTY_NAME  (kernel $(uname -r))"
check "Ubuntu 22.04 (jammy)" '[[ "$VERSION_ID" == "22.04" ]]'

step "ROS 2"
softck "ROS_DISTRO=humble in environment" '[[ "${ROS_DISTRO:-}" == "humble" ]]'
check  "/opt/ros/humble present"           '[[ -f /opt/ros/humble/setup.bash ]]'

step "NVIDIA GPU / driver"
if need_cmd nvidia-smi; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | sed 's/^/    /'
  check "nvidia-smi runs (driver loaded)" 'nvidia-smi -L'
else
  err "nvidia-smi not found"; FAILN=$((FAILN+1))
fi
if need_cmd nvcc; then ok "nvcc (host CUDA toolkit) present"; else
  info "nvcc not on host -- OK: Isaac ROS uses CUDA inside Docker (host toolkit not required)"; fi

step "Docker / GPU container runtime"
softck "docker installed"               'need_cmd docker'
softck "docker compose plugin"          'docker compose version'
softck "nvidia-container-toolkit (nvidia-ctk)" 'need_cmd nvidia-ctk'
if need_cmd docker; then
  softck "user in 'docker' group"       'id -nG | grep -qw docker'
fi

step "Network interfaces"
ip -brief addr | sed 's/^/    /'
if ip link show "${ROS_IFACE}" >/dev/null 2>&1; then
  state="$(cat /sys/class/net/${ROS_IFACE}/operstate 2>/dev/null || echo unknown)"
  if [[ "$state" == "up" ]]; then ok "Robot NIC ${ROS_IFACE} is UP"; PASS=$((PASS+1))
  else warn "Robot NIC ${ROS_IFACE} exists but is '${state}' (bring up before Pi comms)"; WARNN=$((WARNN+1)); fi
else
  warn "Robot NIC ${ROS_IFACE} not present (set ROS_IFACE in env.sh)"; WARNN=$((WARNN+1))
fi
if ip route | grep -q '^default .*tun0\|0.0.0.0/1 .*tun0'; then
  warn "A VPN (tun0) is capturing the default route -- this BREAKS ROS2/DDS discovery to the Pi. Disconnect it for robot work."
  WARNN=$((WARNN+1))
fi

step "Storage"
df -hT / "${DATADRIVE}" 2>/dev/null | sed 's/^/    /'
root_avail_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
if (( root_avail_gb >= 5 )); then ok "Root / has ${root_avail_gb}G free"; PASS=$((PASS+1))
else warn "Root / has only ${root_avail_gb}G free (need >=5G for Docker+ROS install)"; WARNN=$((WARNN+1)); fi
if [[ -d "${DATADRIVE}" ]]; then
  dfs="$(fs_type_of "${DATADRIVE}")"
  if [[ "$dfs" =~ ^(ext4|ext3|xfs|btrfs)$ ]]; then
    dd_avail_gb=$(df -BG --output=avail "${DATADRIVE}" | tail -1 | tr -dc '0-9')
    ok "${DATADRIVE} is ${dfs} with ${dd_avail_gb}G free (Isaac ROS target ready)"; PASS=$((PASS+1))
  else
    warn "${DATADRIVE} is '${dfs}' -- NOT valid for Docker/Isaac ROS. Run provision_datadrive.sh"; WARNN=$((WARNN+1))
  fi
else
  warn "${DATADRIVE} does not exist yet -- run provision_datadrive.sh before Isaac ROS"; WARNN=$((WARNN+1))
fi

step "Summary"
printf "    ${C_GRN}PASS=%d${C_RESET}  ${C_YEL}WARN=%d${C_RESET}  ${C_RED}FAIL=%d${C_RESET}\n" "$PASS" "$WARNN" "$FAILN"
if (( FAILN > 0 )); then die "System verification FAILED -- resolve the red items above."; fi
(( WARNN > 0 )) && warn "System usable, but review the warnings above before live robot bringup."
ok "STEP 1 complete."
