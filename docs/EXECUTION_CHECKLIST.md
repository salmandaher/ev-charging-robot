# Tomorrow's execution checklist (STEP 15)

Run phases **in order**. Each lists the command, what you should see, and the
go/no-go gate. Open separate terminals for long-running launches.

> Pre-req for ALL ROS phases: **disconnect ExpressVPN** (its `tun0` hijacks the
> default route and breaks DDS discovery), and `source ~/.bashrc` in each shell.

---

## Phase 0 — one-time install (do once, today/tonight)
```bash
cd ~/ev_charging_robot
bash scripts/setup_laptop.sh            # steps 1-7 (host). Stops at the ext4 gate.
# provision ext4 first if needed:
bash scripts/provision_datadrive.sh     # shows options; --format when ready
bash scripts/setup_laptop.sh            # re-run: docker move + dirs + isaac clone
bash scripts/enter_container.sh         # build + enter container (long first build)
#   (inside)  scripts/container_setup.sh   # deps + colcon build
```

## Phase 1 — verify Ethernet
```bash
ip -brief addr show eno1
bash scripts/configure_network.sh --setup-eth     # if eno1 is DOWN
ping -c3 <PI_IP>
```
**Expect:** `eno1 ... UP ... 192.168.50.1/24`, ping replies < 1 ms.
**Gate:** Pi reachable. ❌ no reply → check cable/IP/`PI_IP` in `scripts/env.sh`.

## Phase 2 — verify ROS 2 discovery
```bash
bash scripts/verify_network.sh
ros2 node list
```
**Expect:** multicast/peer OK; the Pi's nodes appear (camera, odom).
**Gate:** Pi nodes visible. ❌ none → VPN still up? same `ROS_DOMAIN_ID=10`? same `RMW=rmw_cyclonedds_cpp` on both ends?

## Phase 3 — verify camera topics from the Pi
```bash
bash scripts/verify_ros.sh
ros2 topic hz /camera/color/image_raw
ros2 topic hz /camera/infra1/image_rect_raw      # for cuVSLAM
```
**Expect:** all expected topics present; color ~30 Hz; infra1/2 + imu flowing.
**Gate:** color + depth + (infra1/infra2 + imu) streaming. See `docs/CAMERA_NOTES.md`.

## Phase 4 — visualize camera in RViz
```bash
bash scripts/launch_rviz.sh              # in-container RViz (full displays)
```
**Expect:** RGB + Depth images render; TF shows camera optical frames.
**Gate:** live images in RViz.

## Phase 5 — launch cuVSLAM
```bash
bash scripts/enter_container.sh          # terminal A (leave running)
bash scripts/launch_cuvslam.sh           # terminal B
```
**Expect:** node logs "Visual SLAM initialized / tracking"; `/visual_slam/tracking/odometry` publishes.

## Phase 6 — verify map -> odom
```bash
ros2 run tf2_tools view_frames          # writes frames.pdf
ros2 run tf2_ros tf2_echo map odom
ros2 topic echo /visual_slam/tracking/odometry --once
```
**Expect:** TF chain `map -> odom -> base_link -> camera_link`; `map->odom` transform exists.
**Gate:** TF complete and stable when the robot is still.

## Phase 7 — walk the robot manually
Push/drive the robot slowly around the area.
**Expect:** odometry tracks motion smoothly; pose returns near origin on loop closure; no large jumps.
**Gate:** tracking holds (no "lost"). If it drifts/loses: more light, slower motion, check stereo (emitter), check IMU rate.

## Phase 8 — launch nvblox
```bash
bash scripts/launch_nvblox.sh            # terminal C
```
**Expect:** `/nvblox_node/mesh` and `/nvblox_node/map_slice` publish.

## Phase 9 — verify reconstruction
In RViz the **Nvblox Mesh** colours in as you move; **ESDF slice** shows obstacle distances.
```bash
ros2 topic hz /nvblox_node/mesh
ros2 topic echo /nvblox_node/map_slice --once
```
**Gate:** mesh grows with exploration; slice updates.

## Phase 10 — launch Nav2
```bash
bash scripts/launch_nav2.sh              # terminal D
ros2 lifecycle get /bt_navigator
```
**Expect:** lifecycle nodes reach **active**; `/global_costmap/costmap` + `/local_costmap/costmap` show nvblox obstacles.

## Phase 11 — send a navigation goal
In RViz click **2D Goal Pose**, or:
```bash
ros2 topic pub -1 /goal_pose geometry_msgs/PoseStamped \
'{header: {frame_id: "map"}, pose: {position: {x: 1.0, y: 0.0, z: 0.0}, orientation: {w: 1.0}}}'
```
**Expect:** green global plan + magenta local plan; robot drives to goal, avoiding nvblox obstacles; "Goal reached".

```bash
bash scripts/verify_navigation.sh        # automated end-to-end gate
```

---

## ✅ Final green readiness checklist
```
[ ] Ubuntu 22.04 / ROS2 Humble / RTX 4060 driver 570 / CUDA 12.x   (verify_system.sh)
[ ] Root / has >5 GB free; DataDrive is ext4 with >60 GB free
[ ] Docker + NVIDIA Container Toolkit installed; GPU visible in container
[ ] docker data-root on the ext4 DataDrive
[ ] Host ROS packages installed (nav2, robot_localization, rviz, cyclonedds, ...)
[ ] ROS_DOMAIN_ID=10, RMW=rmw_cyclonedds_cpp, CycloneDDS bound to eno1
[ ] VPN OFF; eno1 UP; Pi pingable
[ ] All Pi topics present; color ~30 Hz; infra1/2 + imu flowing
[ ] Isaac ROS container built; cuVSLAM + nvblox packages visible
[ ] TF: map -> odom -> base_link -> camera_link
[ ] cuVSLAM odometry stable while walking
[ ] nvblox mesh + ESDF updating
[ ] Nav2 lifecycle active; costmaps populated from nvblox
[ ] Goal sent -> robot navigates and avoids obstacles
```
