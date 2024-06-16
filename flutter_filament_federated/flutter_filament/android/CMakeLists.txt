cmake_minimum_required(VERSION 3.10)  

include_directories(../../../dart_filament/native/include)
include_directories(src/main/cpp)
# link_directories(src/main/jniLibs/${ANDROID_ABI}) 
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
set(ANDROID_STL c++_shared)

add_library(flutter_filament_android SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/FlutterFilamentAndroid.cpp"
)

target_link_libraries(
  flutter_filament_android
  -landroid
  -llog
)