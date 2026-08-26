# =============================================================================
#  nav2.launch.py  (STEP 12)  --  Navigation2 for the differential-drive robot
#  Uses nav2_bringup's navigation_launch.py (planner/controller/BT/costmaps) with
#  our nav2_params.yaml. No map_server / AMCL -- cuVSLAM supplies map->odom and
#  nvblox supplies obstacles. Pair with ekf.launch.py for odom->base_link.
# =============================================================================
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration


def generate_launch_description():
    pkg = get_package_share_directory('ev_robot_bringup')
    nav2_bringup = get_package_share_directory('nav2_bringup')
    default_params = os.path.join(pkg, 'config', 'nav2_params.yaml')

    params_file = LaunchConfiguration('params_file')
    autostart = LaunchConfiguration('autostart')

    args = [
        DeclareLaunchArgument('params_file', default_value=default_params),
        DeclareLaunchArgument('autostart', default_value='true'),
    ]

    navigation = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(nav2_bringup, 'launch', 'navigation_launch.py')),
        launch_arguments={
            'use_sim_time': 'false',
            'params_file': params_file,
            'autostart': autostart,
            'use_composition': 'False',   # 'True' targets a nav2_container that nothing starts -> 0 nodes load
        }.items(),
    )

    return LaunchDescription(args + [navigation])
