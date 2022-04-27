lib: 
	mkdir -p build \
		&& cd build \
		&& cmake -DIOS_PLATFORM=OS -DCMAKE_TOOLCHAIN_FILE=../iOS.cmake -GXcode .. \
		&& xcodebuild -configuration Release -target ALL_BUILD \
		&& cd ..

	mkdir -p lib
	cp ./build/cpp_common/Release-iphoneos/libcpp_common.a lib
	cp ./build/rosconsole/Release-iphoneos/librosconsole_backend_interface.a lib
	cp ./build/rosconsole/Release-iphoneos/librosconsole_print.a lib
	cp ./build/rosconsole/Release-iphoneos/librosconsole.a lib
	cp ./build/roscpp/Release-iphoneos/libroscpp.a lib
	cp ./build/roscpp_serialization/Release-iphoneos/libroscpp_serialization.a lib
	cp ./build/rostime/Release-iphoneos/librostime.a lib
	cp ./build/xmlrpcpp/Release-iphoneos/libxmlrpcpp.a lib
	cp ./build/rosbag_storage/Release-iphoneos/librosbag_storage.a lib
	cp ./build/lib/Release/libconsole_bridge.a lib
	cp thirdparty/boost/ios/libboost.a lib

clean: 
	rm -rf lib
	rm -rf build

