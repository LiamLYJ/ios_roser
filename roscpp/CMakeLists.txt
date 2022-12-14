cmake_minimum_required(VERSION 3.2)

project(roscpp)

set(Boost_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../thirdparty/boost/include)
set(catkin_INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../include)
include_directories(include ${catkin_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS})
add_library(roscpp 
  src/libros/master.cpp
  src/libros/network.cpp
  src/libros/subscriber.cpp
  src/libros/common.cpp
  src/libros/publisher_link.cpp
  src/libros/service_publication.cpp
  src/libros/connection.cpp
  src/libros/single_subscriber_publisher.cpp
  src/libros/param.cpp
  src/libros/service_server.cpp
  src/libros/wall_timer.cpp
  src/libros/xmlrpc_manager.cpp
  src/libros/publisher.cpp
  src/libros/timer.cpp
  src/libros/io.cpp
  src/libros/names.cpp
  src/libros/topic.cpp
  src/libros/topic_manager.cpp
  src/libros/poll_manager.cpp
  src/libros/publication.cpp
  src/libros/statistics.cpp
  src/libros/intraprocess_subscriber_link.cpp
  src/libros/intraprocess_publisher_link.cpp
  src/libros/callback_queue.cpp
  src/libros/service_server_link.cpp
  src/libros/service_client.cpp
  src/libros/node_handle.cpp
  src/libros/connection_manager.cpp
  src/libros/file_log.cpp
  src/libros/transport/transport.cpp
  src/libros/transport/transport_udp.cpp
  src/libros/transport/transport_tcp.cpp
  src/libros/subscriber_link.cpp
  src/libros/service_client_link.cpp
  src/libros/transport_publisher_link.cpp
  src/libros/transport_subscriber_link.cpp
  src/libros/service_manager.cpp
  src/libros/rosout_appender.cpp
  src/libros/init.cpp
  src/libros/subscription.cpp
  src/libros/subscription_queue.cpp
  src/libros/spinner.cpp
  src/libros/internal_timer_manager.cpp
  src/libros/message_deserializer.cpp
  src/libros/poll_set.cpp
  src/libros/service.cpp
  src/libros/this_node.cpp
)