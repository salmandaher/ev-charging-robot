# =============================================================================
#  robot.launch.py  --  full-system bringup (cuVSLAM + nvblox + EKF + Nav2 + RViz)
#  Toggle components with launch args, e.g.:
#     ros2 launch ev_robot_bringup robot.launch.py nav2:=false rviz:=true
#  Recommended incremental order is in docs/EXECUTION_CHECKLIST.md; this file is
#  for when each layer is already trusted.
# =============================================================================
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, GroupAction
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch_ros.actions import Node


def _inc(pkg_share, rel, condition_key, extra=None):
    cond = IfCondition(LaunchConfiguration(condition_key))
    return IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(pkg_share, 'launch', rel)),
        condition=cond,
        launch_arguments=(extra or {}).items(),
    )


def generate_launch_description():
    pkg = get_package_share_directory('ev_robot_bringup')
    rviz_cfg = os.path.join(pkg, 'rviz', 'ev_robot.rviz')

    args = [
        DeclareLaunchArgument('vslam', default_value='true'),
        DeclareLaunchArgument('nvblox', default_value='true'),
        DeclareLaunchArgument('ekf', default_value='false'),   # off until wheel odom verified
        DeclareLaunchArgument('nav2', default_value='true'),
        DeclareLaunchArgument('rviz', default_value='true'),
    ]

    # If the EKF owns odom->base_link, cuVSLAM must NOT also publish it.
    vslam = _inc(pkg, 'visual_slam.launch.py', 'vslam', {
        'publish_odom_to_base': PythonExpression(
            ["'false' if '", LaunchConfiguration('ekf'), "' == 'true' else 'true'"]),
    })
    nvblox = _inc(pkg, 'nvblox.launch.py', 'nvblox')
    ekf = _inc(pkg, 'ekf.launch.py', 'ekf')
    nav2 = _inc(pkg, 'nav2.launch.py', 'nav2')

    rviz = Node(
        package='rviz2', executable='rviz2', name='rviz2',
        arguments=['-d', rviz_cfg], output='screen',
        condition=IfCondition(LaunchConfiguration('rviz')),
    )

    return LaunchDescription(args + [vslam, nvblox, ekf, nav2, rviz])
