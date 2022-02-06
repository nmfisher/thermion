cmake_minimum_required(VERSION 3.4.1)  

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(src/main/cpp)
link_directories(src/main/libs/${ANDROID_ABI}) # don't use jniLibs here because we just want to link against these libraries, the actual .so files will be copied by the AAR dependencies
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
add_library( 
            filament_interop
            SHARED
            src/main/cpp/filament_api.cpp
            ../ios/src/FilamentViewer.cpp
            # ../ios/src/Utils.cpp
            # ../ios/src/HDRLoader.cpp
            # ../ios/include/common/NioUtils.cpp
            #../ios/src/morph/GPUMorphHelper.cpp
        )


target_link_libraries(filament_interop -landroid -llog -lfilament-jni -lfilament-utils-jni -lgltfio-jni )

