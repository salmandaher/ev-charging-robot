# =============================================================================
#  nvblox.launch.py  (STEP 11)  --  Isaac ROS Nvblox 3D reconstruction + ESDF
#
#  Inputs : D435i color + aligned depth (from the Pi) and the camera pose via TF
#           (provided by cuVSLAM: map->odom->base_link->camera_link).
#  Outputs: TSDF mesh (RViz), 2D ESDF slice / costmap for Nav2.
#
#  Run cuVSLAM (visual_slam.launch.py) FIRST so the TF pose exists.
# =============================================================================
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode


def generate_launch_description():
    pkg = get_package_share_directory('ev_robot_bringup')
    default_params = os.path.join(pkg, 'config', 'nvblox.yaml')

    args = [
        DeclareLaunchArgument('nvblox_params', default_value=default_params),
        DeclareLaunchArgument('global_frame', default_value='odom'),
    ]

    nvblox_node = ComposableNode(
        name='nvblox_node',
        package='nvblox_ros',
        plugin='nvblox::NvbloxNode',
        parameters=[
            LaunchConfiguration('nvblox_params'),
            {'global_frame': LaunchConfiguration('global_frame')},
        ],
        remappings=[
            # ---- camera 0: depth ----
            ('camera_0/depth/image', '/camera/aligned_depth_to_color/image_raw'),
            ('camera_0/depth/camera_info', '/camera/aligned_depth_to_color/camera_info'),
            # ---- camera 0: color ----
            ('camera_0/color/image', '/camera/color/image_raw'),
            ('camera_0/color/camera_info', '/camera/color/camera_info'),
        ],
    )

    container = ComposableNodeContainer(
        name='nvblox_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container_mt',
        composable_node_descriptions=[nvblox_node],
        output='screen',
    )

    return LaunchDescription(args + [container])
