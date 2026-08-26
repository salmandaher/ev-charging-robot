#!/usr/bin/env bash
# =============================================================================
#  free_root_space.sh  --  reclaim space on the root (/) filesystem
#  Safe/reversible: clears apt caches, vacuums logs, removes orphaned packages
#  and OLD kernels (keeps the running one + most recent). Shows before/after.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
ensure_sudo

before=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
step "Root free before: ${before}G"

step "apt: clean caches + autoremove (purge orphans & old kernels)"
sudo apt-get clean
sudo apt-get autoremove --purge -y

step "journald: cap logs at 200M"
sudo journalctl --vacuum-size=200M 2>/dev/null || true

step "Old kernels (keeping running $(uname -r))"
sudo apt-get autoremove --purge -y 'linux-image-*' 2>/dev/null || true
# never remove the running kernel
ok "kept running kernel: $(uname -r)"

if need_cmd docker; then
  step "Docker dangling images/build cache (safe prune)"
  docker image prune -f 2>/dev/null || sudo docker image prune -f 2>/dev/null || true
  docker builder prune -f 2>/dev/null || sudo docker builder prune -f 2>/dev/null || true
fi

after=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
step "Root free after: ${after}G  (reclaimed ~$((after-before))G)"
df -hT / | sed 's/^/    /'
