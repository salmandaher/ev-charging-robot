# =============================================================================
#  ekf.launch.py  (STEP 12)  --  robot_localization EKF (odom->base_link)
#  Fuses /odom (wheel) + /camera/imu. Launch cuVSLAM with
#  publish_odom_to_base:=false when using this so only the EKF owns odom->base.
# =============================================================================
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    pkg = get_package_share_directory('ev_robot_bringup')
    default_params = os.path.join(pkg, 'config', 'ekf.yaml')

    return LaunchDescription([
        DeclareLaunchArgument('ekf_params', default_value=default_params),
        Node(
            package='robot_localization',
            executable='ekf_node',
            name='ekf_filter_node',
            output='screen',
            parameters=[LaunchConfiguration('ekf_params')],
            remappings=[('odometry/filtered', '/odometry/filtered')],
        ),
    ])
