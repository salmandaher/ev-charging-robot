# D435i camera notes — what the Pi must publish

The laptop runs all perception, but it can only work with what the Pi streams.
cuVSLAM and nvblox want **different** things from the D435i.

## cuVSLAM (Isaac ROS Visual SLAM) — wants STEREO + IMU
cuVSLAM is a **stereo visual-inertial** system. The most robust input is the
D435i's two **infrared** cameras (a real stereo pair) plus the IMU:

| Purpose      | Topic                                  |
|--------------|----------------------------------------|
| left stereo  | `/camera/infra1/image_rect_raw` (+ `/camera/infra1/camera_info`) |
| right stereo | `/camera/infra2/image_rect_raw` (+ `/camera/infra2/camera_info`) |
| imu          | `/camera/imu`                          |

> The spec's `/camera/color/image_raw` + `/camera/aligned_depth_to_color/*` are
> great for **nvblox** but are mono+depth for SLAM — workable but less robust.
> `visual_slam.launch.py` defaults to the infra stereo pair.

**IR emitter caveat:** the D435i projects an IR dot pattern to help depth. That
pattern *hurts* stereo feature matching for cuVSLAM. Two good options:
- Turn the emitter **off** for best VSLAM, accept slightly noisier nvblox depth, **or**
- Use **emitter on/off alternating** (`emitter_on_off:=true`) so odd frames have
  the pattern (for depth) and even frames don't (for stereo).

## nvblox — wants COLOR + ALIGNED DEPTH (+ pose from TF)
| Purpose | Topic |
|---------|-------|
| depth   | `/camera/aligned_depth_to_color/image_raw` (+ `camera_info`) |
| color   | `/camera/color/image_raw` (+ `camera_info`) |
| pose    | via TF (provided by cuVSLAM: `…->camera_link->…optical_frame`) |

## Recommended Pi-side RealSense launch (realsense2_camera)
```bash
ros2 launch realsense2_camera rs_launch.py \
  enable_infra1:=true enable_infra2:=true \
  enable_color:=true  enable_depth:=true \
  align_depth.enable:=true \
  enable_gyro:=true enable_accel:=true \
  unite_imu_method:=2 \
  enable_sync:=true \
  depth_module.emitter_on_off:=true \
  rgb_camera.profile:=640x480x30 \
  depth_module.profile:=640x480x30
```
Lower resolution / framerate = less Ethernet bandwidth and lower laptop load.
Start at 640x480x30; raise only if the link and GPU keep up.

## TF / odometry ownership (important)
The target tree is `map -> odom -> base_link -> camera_link -> <optical frames>`.

- `map -> odom`  : **cuVSLAM** (`publish_map_to_odom_tf:=true`)
- `odom -> base_link` : pick **one** owner —
  - standalone bringup (Phases 5–6): **cuVSLAM** (`publish_odom_to_base:=true`, default), or
  - with wheel odom: **robot_localization EKF** (then launch cuVSLAM with `publish_odom_to_base:=false`)
- `base_link -> camera_link` : static mounting transform (set the measured offset
  in `visual_slam.launch.py` `cam_x/cam_y/cam_z/…`)
- `camera_link -> *_optical_frame` : published by the Pi's RealSense node (`/tf_static`)

> **On the Pi:** publish wheel odometry as the **/odom topic only** — do NOT also
> broadcast an `odom->base_link` TF from the PRIZM bridge, or it will fight
> cuVSLAM/EKF for that edge. Exactly one node may own `odom->base_link`.
