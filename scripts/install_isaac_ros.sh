#!/usr/bin/env bash
# =============================================================================
#  install_isaac_ros.sh  (STEP 6)  --  Isaac ROS Common + Visual SLAM + Nvblox
#  Clones the required NVIDIA repos into the colcon workspace on the ext4
#  DataDrive, configures the dev-container workspace var, and builds the Isaac
#  ROS dev image. cuVSLAM/nvblox packages are then apt-installed INSIDE the
#  container (NVIDIA's supported path) -- run the printed in-container commands.
#
#  Follows the official NVIDIA Isaac ROS dev-container workflow:
#    https://nvidia-isaac-ros.github.io/getting_started/dev_env_setup.html
# =============================================================================
source "$(dirname "$0")/lib/common.sh"
require_not_root
need_cmd docker || die "Docker missing. Run install_docker.sh first."
need_cmd git    || { ensure_sudo; sudo apt-get install -y -qq git git-lfs; }

print_config

# ---- hard storage gate ------------------------------------------------------
step "Storage pre-flight (Isaac ROS images need ~60 GB ext4)"
[[ -d "${DATADRIVE}" ]] || die "${DATADRIVE} missing. Run provision_datadrive.sh first."
require_posix_fs "${ISAAC_ROS_WS%/*}" "Isaac ROS workspace"
DR="$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo /var/lib/docker)"
require_posix_fs "$DR" "Docker data-root"
case "$(fs_type_of "$DR")" in ext4|ext3|xfs|btrfs) : ;; *) die "Docker data-root '$DR' is not ext4. Run configure_docker.sh first.";; esac
avail_gb=$(df -BG --output=avail "$DR" | tail -1 | tr -dc '0-9')
(( avail_gb >= 50 )) || warn "Only ${avail_gb}G free where docker stores images -- Isaac ROS may not fit (want >=60G)."
ok "Storage OK: docker images on $(fs_type_of "$DR") with ${avail_gb}G free"

# ---- workspace + git-lfs ----------------------------------------------------
mkdir_user "${ISAAC_ROS_WS}/src"
git lfs install --skip-repo 2>/dev/null || true

clone_or_update() { # repo_name
  local name="$1" dst="${ISAAC_ROS_WS}/src/$1"
  local url="https://github.com/NVIDIA-ISAAC-ROS/${name}.git"
  if [[ -d "$dst/.git" ]]; then
    step "Updating ${name} (${ISAAC_ROS_RELEASE})"
    git -C "$dst" fetch --depth 1 origin "${ISAAC_ROS_RELEASE}" && git -C "$dst" checkout "${ISAAC_ROS_RELEASE}" && git -C "$dst" reset --hard "origin/${ISAAC_ROS_RELEASE}"
  else
    step "Cloning ${name} (${ISAAC_ROS_RELEASE})"
    git clone --depth 1 -b "${ISAAC_ROS_RELEASE}" "$url" "$dst" \
      || git clone --depth 1 -b main "$url" "$dst"   # fallback if release tag absent
  fi
  ok "${name} ready at $dst"
}
for r in "${ISAAC_ROS_REPOS[@]}"; do clone_or_update "$r"; done

# ---- persist ISAAC_ROS_WS for the dev-container scripts ----------------------
step "Persisting ISAAC_ROS_WS in ~/.bashrc"
if ! grep -q 'ISAAC_ROS_WS=' "$HOME/.bashrc" 2>/dev/null; then
  {
    echo ""
    echo "# Isaac ROS workspace (EV charging robot)"
    echo "export ISAAC_ROS_WS=${ISAAC_ROS_WS}"
  } >> "$HOME/.bashrc"
  ok "added export ISAAC_ROS_WS=${ISAAC_ROS_WS}"
else
  ok "ISAAC_ROS_WS already in ~/.bashrc"
fi
export ISAAC_ROS_WS

# ---- build the Isaac ROS dev image ------------------------------------------
RUN_DEV="${ISAAC_ROS_WS}/src/isaac_ros_common/scripts/run_dev.sh"
[[ -f "$RUN_DEV" ]] || die "run_dev.sh not found at $RUN_DEV (clone of isaac_ros_common failed?)"
chmod +x "${ISAAC_ROS_WS}/src/isaac_ros_common/scripts/"*.sh 2>/dev/null || true

step "Building the Isaac ROS dev container image (long: pulls multi-GB base)"
warn "run_dev.sh is INTERACTIVE (it drops you into the container). It is the"
warn "official entry point and builds the image on first run."
echo
cat <<EOF
    Run these now (this script has done all the host-side prep):

    ${C_CYN}# 1) Build + enter the Isaac ROS dev container${C_RESET}
    cd ${ISAAC_ROS_WS}/src/isaac_ros_common
    ./scripts/run_dev.sh ${ISAAC_ROS_WS}

    ${C_CYN}# 2) INSIDE the container -- install cuVSLAM + nvblox (NVIDIA apt packages)${C_RESET}
    sudo apt-get update
    sudo apt-get install -y \\
        ros-humble-isaac-ros-visual-slam \\
        ros-humble-isaac-ros-nvblox \\
        ros-humble-isaac-ros-examples \\
        ros-humble-isaac-ros-realsense

    ${C_CYN}# 3) INSIDE the container -- build the cloned source (vslam/nvblox launch files)${C_RESET}
    cd /workspaces/isaac_ros-dev
    colcon build --symlink-install --parallel-workers 6
    source install/setup.bash

    ${C_CYN}# 4) Verify packages are visible${C_RESET}
    ros2 pkg list | grep -E "isaac_ros_visual_slam|nvblox"
EOF

step "STEP 6 host-side prep complete"
ok "Repos cloned to ${ISAAC_ROS_WS}/src ; ISAAC_ROS_WS exported."
warn "Limit colcon to '--parallel-workers 6' on this 15GB-RAM machine to avoid OOM."
