cmake_minimum_required(VERSION 3.2)

project(rosconsole)

set(Boost_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty/boost/include)
set(catkin_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../include)
set(ROSCONSOLE_BACKEND "print")
include_directories(include ${catkin_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS})
add_library(rosconsole_backend_interface src/rosconsole/rosconsole_backend.cpp)
add_library(rosconsole src/rosconsole/rosconsole.cpp)
add_library(rosconsole_print src/rosconsole/impl/rosconsole_print.cpp)
