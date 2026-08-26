#!/usr/bin/env bash
# =============================================================================
#  install_docker.sh  (STEP 2)  --  Docker Engine + Compose + NVIDIA Container Toolkit
#  Idempotent. Uses official Docker + NVIDIA apt repos. Verifies GPU passthrough.
#  NOTE: this installs the engine to the DEFAULT data-root (/var/lib/docker on /).
#        Move it to the ext4 DataDrive afterwards with configure_docker.sh BEFORE
#        pulling large Isaac ROS images.
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
ensure_sudo

# ---------------------------------------------------------------- Docker engine
if need_cmd docker && docker --version >/dev/null 2>&1; then
  ok "Docker already installed: $(docker --version)"
else
  step "Installing Docker Engine (official repo)"
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
                             docker-buildx-plugin docker-compose-plugin
  ok "Installed: $(docker --version)"
fi

# ---------------------------------------------------------- docker group access
if id -nG "$USER" | grep -qw docker; then
  ok "User '$USER' already in docker group"
else
  step "Adding '$USER' to docker group"
  sudo usermod -aG docker "$USER"
  warn "Group change takes effect on next login. For THIS shell run:  newgrp docker"
fi

# -------------------------------------------------- NVIDIA Container Toolkit
if need_cmd nvidia-ctk; then
  ok "NVIDIA Container Toolkit already installed: $(nvidia-ctk --version | head -1)"
else
  step "Installing NVIDIA Container Toolkit (official repo)"
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq nvidia-container-toolkit
  ok "Installed: $(nvidia-ctk --version | head -1)"
fi

# -------------------------------------------- register nvidia runtime w/ docker
step "Configuring docker runtime for NVIDIA GPUs"
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
ok "nvidia runtime registered, docker restarted"

# --------------------------------------------------------------- verification
step "Verifying Docker"
sudo docker run --rm hello-world >/dev/null && ok "docker run hello-world OK" \
  || die "hello-world failed -- docker not functional"

step "Verifying GPU passthrough into containers"
if sudo docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi -L; then
  ok "GPU visible inside container -- NVIDIA Container Toolkit working"
else
  die "GPU NOT visible in container. Check 'nvidia-ctk runtime configure' and driver."
fi

step "STEP 2 complete"
info "Docker + Compose + NVIDIA Container Toolkit installed and GPU-verified."
warn "Next: move docker data-root to ext4 DataDrive  ->  bash scripts/configure_docker.sh"
warn "If 'docker' still needs sudo in this shell, run:  newgrp docker   (or log out/in)"
