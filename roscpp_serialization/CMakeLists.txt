cmake_minimum_required(VERSION 3.2)

project(roscpp_serialization)

set(Boost_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty/boost/include)
set(catkin_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../include)
include_directories(include ${catkin_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS})
add_library(roscpp_serialization src/serialization.cpp)