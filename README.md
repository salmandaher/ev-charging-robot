# EV-charging robot — laptop perception & autonomy stack

All perception/autonomy runs on this **laptop** (ASUS TUF A15, Ryzen 7 7435HS,
**RTX 4060 8 GB**, 15 GB RAM, Ubuntu 22.04, ROS 2 Humble). The **Raspberry Pi
does zero perception** — it only streams the D435i + wheel odometry over Ethernet.

Laptop stack: **Isaac ROS Visual SLAM (cuVSLAM) → Isaac ROS Nvblox (ESDF) →
Nav2**, with robot_localization, RViz2, CycloneDDS.

---

## ⚠️ Current machine state (read before running) — found 2026-06-22
Three things block a blind run of the original plan; the scripts handle/guard them:

1. **`/DataDrive` target is NTFS.** `/media/salman/DataDrive1` (`nvme0n1p7`) is an
   NTFS/FUSE Windows partition. Docker overlay2 + colcon **cannot** run there.
   `/DataDrive` does not exist yet. → Provision an **ext4** mount with
   `scripts/provision_datadrive.sh` (reformat that partition, add an external
   SSD, or carve a new partition). Every storage-touching script refuses NTFS.
2. **Root `/` is small (64 GB).** Fine for Docker + ROS packages once ~5 GB+ is
   free (`scripts/free_root_space.sh`), but the full Isaac ROS image stack
   (~60 GB) must live on the ext4 DataDrive, not root.
3. **VPN + Ethernet.** ExpressVPN (`tun0`) captures the default route → it
   **breaks DDS discovery** to the Pi; disconnect it for robot work. Wired
   `eno1` was DOWN; `configure_network.sh --setup-eth` brings it up.

`nvcc` not being on the host is **fine** — Isaac ROS uses CUDA inside Docker.

---

## Layout
```
ev_charging_robot/
├─ scripts/                 host scripts (idempotent; stop on failure)
│  ├─ env.sh                ← central config (paths, ROS_DOMAIN_ID, PI_IP, iface)
│  ├─ lib/common.sh         logging, guards, fs safety, container helpers
│  ├─ setup_laptop.sh       master orchestrator (STEPS 1-7 + isaac prep)
│  ├─ verify_system.sh                      STEP 1
│  ├─ install_docker.sh                     STEP 2
│  ├─ provision_datadrive.sh / configure_docker.sh   STEP 3 (+5)
│  ├─ install_ros_packages.sh / create_directories.sh STEP 4 / 5
│  ├─ install_isaac_ros.sh                  STEP 6
│  ├─ configure_network.sh                  STEP 7
│  ├─ verify_network.sh / verify_ros.sh     STEP 8/9
│  ├─ enter_container.sh / sync_to_workspace.sh
│  ├─ launch_cuvslam.sh / launch_nvblox.sh / launch_nav2.sh / launch_rviz.sh
│  ├─ verify_navigation.sh
│  ├─ free_root_space.sh
│  └─ container/            scripts that run INSIDE the Isaac ROS container
│     ├─ container_setup.sh (deps + colcon build)
│     └─ launch_*.sh
├─ ros2_ws_src/ev_robot_bringup/   ROS 2 package (synced into the workspace)
│  ├─ launch/   visual_slam | nvblox | nav2 | ekf | robot (full)
│  ├─ config/   nvblox.yaml | nav2_params.yaml | ekf.yaml
│  └─ rviz/     ev_robot.rviz                STEP 13
├─ config/cyclonedds/cyclonedds.xml         STEP 7 (regenerated from env.sh)
└─ docs/  CAMERA_NOTES.md | EXECUTION_CHECKLIST.md   STEP 15
```

## Quick start
```bash
cd ~/ev_charging_robot
nano scripts/env.sh                 # set PI_IP, ROS_IFACE, DATADRIVE, etc.
bash scripts/setup_laptop.sh        # host install; stops at the ext4 gate
bash scripts/provision_datadrive.sh # make /DataDrive ext4 (see its options)
bash scripts/setup_laptop.sh        # finish: docker data-root + dirs + isaac clone
bash scripts/enter_container.sh     #   then (inside): scripts/container_setup.sh
```
Then follow **docs/EXECUTION_CHECKLIST.md** Phases 1–11.

## Architecture
```
 Raspberry Pi (sensors only)              Laptop (all compute, Docker)
 ┌───────────────────────────┐  GbE/DDS  ┌──────────────────────────────────┐
 │ D435i: color/depth/infra/imu ───────────▶ cuVSLAM ── map->odom (+odom->base)│
 │ wheel odom (PRIZM) /odom   │           │   │ pose via TF                    │
 └───────────────────────────┘           │   ▼                                │
                                          │ nvblox ── TSDF mesh + 2D ESDF slice│
                                          │   │                                │
                                          │   ▼                                │
                                          │ Nav2 (RPP ctrl + Smac planner)     │
                                          │   nvblox costmap layer ── /cmd_vel ─┼──▶ Pi base
                                          │ robot_localization EKF (optional)  │
                                          │ RViz2 / Foxglove                   │
                                          └──────────────────────────────────┘
```

## TF tree
```
map ──(cuVSLAM)──▶ odom ──(cuVSLAM or EKF)──▶ base_link ──(static)──▶ camera_link ──(Pi)──▶ *_optical_frame
```
See `docs/CAMERA_NOTES.md` for who owns each edge and the D435i streaming config.

## Network
`ROS_DOMAIN_ID=10`, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, `ROS_LOCALHOST_ONLY=0`,
CycloneDDS bound to `eno1` with the Pi as a unicast peer (`config/cyclonedds/cyclonedds.xml`).
The **Pi must use the same domain + cyclonedds RMW**. Keep the VPN off.
