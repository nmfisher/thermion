cmake_minimum_required(VERSION 3.10)

# This JNI shim only uses C/JNI/Android APIs. Thermion's sole C++ runtime is
# linked statically into libthermion_dart.so by its native-assets build hook.
project(thermion_flutter_android LANGUAGES C CXX)

include_directories(src/main/include)
include_directories(src/main/cpp)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
add_compile_definitions(ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES ON)

add_library(thermion_flutter_android SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/ThermionFlutterAndroid.cpp"
)

target_link_libraries(
  thermion_flutter_android
  -landroid
  -llog
)

target_link_options(
  thermion_flutter_android
  PRIVATE
  -Wl,-z,max-page-size=16384
)
