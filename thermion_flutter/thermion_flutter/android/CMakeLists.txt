cmake_minimum_required(VERSION 3.10)  

include_directories(src/main/include)
include_directories(src/main/cpp)
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