# =============================================================================
#  visual_slam.launch.py  (STEP 10)  --  Isaac ROS Visual SLAM (cuVSLAM)
#
#  Consumes the D435i streams published by the Raspberry Pi and produces the
#  TF tree:   map -> odom -> base_link -> camera_link -> <camera optical frames>
#
#  cuVSLAM is a STEREO visual-inertial system. By default this launch uses the
#  D435i infrared stereo pair (best accuracy). Have the Pi publish:
#     /camera/infra1/image_rect_raw  /camera/infra1/camera_info
#     /camera/infra2/image_rect_raw  /camera/infra2/camera_info
#     /camera/imu
#  See docs/CAMERA_NOTES.md. Set use_color:=true to fall back to the color+depth
#  topics from the spec (mono+depth; less robust for SLAM).
# =============================================================================
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch_ros.actions import ComposableNodeContainer, Node
from launch_ros.descriptions import ComposableNode


def generate_launch_description():
    args = [
        DeclareLaunchArgument('base_frame', default_value='base_link'),
        DeclareLaunchArgument('map_frame', default_value='map'),
        DeclareLaunchArgument('odom_frame', default_value='odom'),
        DeclareLaunchArgument('camera_frame', default_value='camera_link'),
        DeclareLaunchArgument('imu_frame', default_value='camera_imu_optical_frame'),
        # cuVSLAM should own map->odom AND odom->base_link for standalone bringup
        # (Phases 5-6). When you bring up robot_localization later, set
        # publish_odom_to_base:=false and let the EKF own odom->base_link.
        DeclareLaunchArgument('publish_map_to_odom', default_value='true'),
        DeclareLaunchArgument('publish_odom_to_base', default_value='true'),
        DeclareLaunchArgument('enable_imu_fusion', default_value='true'),
        # base_link -> camera_link mounting offset (METERS / RADIANS). MEASURE THESE.
        DeclareLaunchArgument('cam_x', default_value='0.20'),
        DeclareLaunchArgument('cam_y', default_value='0.0'),
        DeclareLaunchArgument('cam_z', default_value='0.25'),
        DeclareLaunchArgument('cam_roll', default_value='0.0'),
        DeclareLaunchArgument('cam_pitch', default_value='0.0'),
        DeclareLaunchArgument('cam_yaw', default_value='0.0'),
    ]

    base_frame = LaunchConfiguration('base_frame')
    map_frame = LaunchConfiguration('map_frame')
    odom_frame = LaunchConfiguration('odom_frame')
    camera_frame = LaunchConfiguration('camera_frame')
    imu_frame = LaunchConfiguration('imu_frame')

    # ---- static mounting transform: base_link -> camera_link ----------------
    static_cam_tf = Node(
        package='tf2_ros', executable='static_transform_publisher', name='base_to_camera',
        arguments=[
            LaunchConfiguration('cam_x'), LaunchConfiguration('cam_y'), LaunchConfiguration('cam_z'),
            LaunchConfiguration('cam_yaw'), LaunchConfiguration('cam_pitch'), LaunchConfiguration('cam_roll'),
            base_frame, camera_frame,
        ],
        output='screen',
    )

    # ---- cuVSLAM composable node --------------------------------------------
    visual_slam_node = ComposableNode(
        name='visual_slam_node',
        package='isaac_ros_visual_slam',
        plugin='nvidia::isaac_ros::visual_slam::VisualSlamNode',
        parameters=[{
            'num_cameras': 2,                 # stereo
            'enable_image_denoising': False,
            'rectified_images': True,         # infraX/image_rect_raw is already rectified
            'enable_imu_fusion': LaunchConfiguration('enable_imu_fusion'),
            'gyro_noise_density': 0.000244,
            'gyro_random_walk': 0.000019393,
            'accel_noise_density': 0.001862,
            'accel_random_walk': 0.003,
            'calibration_frequency': 200.0,
            'image_jitter_threshold_ms': 34.0,
            'enable_localization_n_mapping': True,
            'enable_slam_visualization': True,
            'enable_landmarks_view': True,
            'enable_observations_view': True,
            'map_frame': map_frame,
            'odom_frame': odom_frame,
            'base_frame': base_frame,
            'imu_frame': imu_frame,
            'publish_map_to_odom_tf': LaunchConfiguration('publish_map_to_odom'),
            'publish_odom_to_base_tf': LaunchConfiguration('publish_odom_to_base'),
            'invert_map_to_odom_tf': False,
            'publish_tf': True,
            'image_qos': 'SENSOR_DATA',
        }],
        remappings=[
            ('visual_slam/image_0', '/camera/infra1/image_rect_raw'),
            ('visual_slam/camera_info_0', '/camera/infra1/camera_info'),
            ('visual_slam/image_1', '/camera/infra2/image_rect_raw'),
            ('visual_slam/camera_info_1', '/camera/infra2/camera_info'),
            ('visual_slam/imu', '/camera/imu'),
        ],
    )

    container = ComposableNodeContainer(
        name='visual_slam_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container_mt',
        composable_node_descriptions=[visual_slam_node],
        output='screen',
    )

    return LaunchDescription(args + [static_cam_tf, container])
