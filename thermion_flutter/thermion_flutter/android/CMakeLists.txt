cmake_minimum_required(VERSION 3.10)  

include_directories(../../../thermion_dart/native/include)
include_directories(src/main/cpp)
# link_directories(src/main/jniLibs/${ANDROID_ABI}) 
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
set(ANDROID_STL c++_shared)

add_library(thermion_flutter_android SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/ThermionFlutterAndroid.cpp"
)

target_link_libraries(
  thermion_flutter_android
  -landroid
  -llog
)