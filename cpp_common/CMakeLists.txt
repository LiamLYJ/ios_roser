cmake_minimum_required(VERSION 3.2)

project(cpp_common)

set(console_bridge_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty/console_bridge/include ${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty/console_bridge/build)
set(Boost_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty/boost/include)
set(catkin_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../include)
include_directories(include ${catkin_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS} ${console_bridge_INCLUDE_DIRS})
add_library(${PROJECT_NAME} src/debug.cpp src/header.cpp)
