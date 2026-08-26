cmake_minimum_required(VERSION 3.8)
project(ev_robot_bringup)

find_package(ament_cmake REQUIRED)

# Install launch files, params, and RViz configs so they ship with the package.
install(DIRECTORY launch config rviz
        DESTINATION share/${PROJECT_NAME})

ament_package()
