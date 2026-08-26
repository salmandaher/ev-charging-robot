#!/usr/bin/env bash
# =============================================================================
#  configure_docker.sh  (STEP 3)  --  move Docker data-root to the ext4 DataDrive
#  Writes /etc/docker/daemon.json, migrates existing images, restarts, verifies.
#  Refuses to point Docker at a non-POSIX (NTFS/FUSE) filesystem.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
need_cmd docker || die "Docker not installed. Run install_docker.sh first."
ensure_sudo

print_config

step "Validating target filesystem"
mkdir_user "${DATADRIVE}" 2>/dev/null || sudo mkdir -p "${DATADRIVE}"
require_posix_fs "${DATADRIVE}" "Docker data-root"   # hard stop if NTFS/FUSE/FAT
sudo mkdir -p "${DOCKER_DATA_ROOT}"

# ---- current data-root ------------------------------------------------------
CUR_ROOT="$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo /var/lib/docker)"
info "Current docker data-root: ${CUR_ROOT}"
if [[ "$CUR_ROOT" == "${DOCKER_DATA_ROOT}" ]]; then
  ok "Docker already using ${DOCKER_DATA_ROOT}. Verifying daemon.json only."
fi

# ---- write daemon.json (merge-safe) ----------------------------------------
step "Writing /etc/docker/daemon.json"
sudo mkdir -p /etc/docker
[[ -f /etc/docker/daemon.json ]] && sudo cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%s 2>/dev/null || echo prev)" 2>/dev/null || true
sudo tee /etc/docker/daemon.json >/dev/null <<JSON
{
  "data-root": "${DOCKER_DATA_ROOT}",
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
JSON
ok "daemon.json written (data-root + nvidia default runtime + log rotation)"

# ---- migrate existing data (only if moving and source non-empty) -----------
if [[ "$CUR_ROOT" != "${DOCKER_DATA_ROOT}" && -d "$CUR_ROOT" ]]; then
  if sudo test -n "$(sudo ls -A "$CUR_ROOT" 2>/dev/null)"; then
    step "Migrating existing Docker data ${CUR_ROOT} -> ${DOCKER_DATA_ROOT}"
    sudo systemctl stop docker docker.socket 2>/dev/null || true
    sudo rsync -aP "${CUR_ROOT}/" "${DOCKER_DATA_ROOT}/"
    ok "Migration complete (old data left in place at ${CUR_ROOT} as backup)"
  fi
fi

# ---- restart + verify -------------------------------------------------------
step "Restarting Docker"
sudo systemctl restart docker
sleep 2 2>/dev/null || true
NEW_ROOT="$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || sudo docker info -f '{{.DockerRootDir}}')"
[[ "$NEW_ROOT" == "${DOCKER_DATA_ROOT}" ]] \
  && ok "Verified: docker data-root = ${NEW_ROOT}" \
  || die "data-root is '${NEW_ROOT}', expected '${DOCKER_DATA_ROOT}'. Check daemon.json / journalctl -u docker"

DEFRT="$(docker info -f '{{.DefaultRuntime}}' 2>/dev/null || true)"
[[ "$DEFRT" == "nvidia" ]] && ok "Default runtime = nvidia" || warn "Default runtime = ${DEFRT} (expected nvidia)"

step "STEP 3 complete"
df -hT "${DATADRIVE}" | sed 's/^/    /'
warn "Once verified, you may reclaim root space:  sudo rm -rf ${CUR_ROOT}   (only if old & unused)"
