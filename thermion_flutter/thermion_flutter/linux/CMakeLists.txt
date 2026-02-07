cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_flutter")
project(${PROJECT_NAME} LANGUAGES C CXX)
set(PLUGIN_NAME "thermion_flutter_plugin")

add_library(${PLUGIN_NAME} SHARED
  "thermion_flutter_plugin.cc"
  "egl_texture.cc"
)

set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

# thermion_dart native-assets output
# Flutter places native-assets at: <project>/build/native_assets/linux/
# CMake build dir is: <project>/build/linux/x64/{release,debug}/
# So relative path from CMAKE_BINARY_DIR is ../../../native_assets/linux/
set(NATIVE_ASSETS_DIR "${CMAKE_BINARY_DIR}/../../../native_assets/linux")

target_include_directories(${PLUGIN_NAME} PRIVATE "${NATIVE_ASSETS_DIR}")
target_link_directories(${PLUGIN_NAME} PRIVATE "${NATIVE_ASSETS_DIR}")

# thermion_dart.so has unresolved basisu/draco encoder symbols (pulled in by
# --whole-archive on filamat). These code paths are never called at runtime.
# Propagate --allow-shlib-undefined to the executable that links against this plugin.
set_property(TARGET ${PLUGIN_NAME} APPEND PROPERTY
  INTERFACE_LINK_OPTIONS "-Wl,--allow-shlib-undefined")

target_compile_options(${PLUGIN_NAME} PRIVATE -stdlib=libc++)
target_link_options(${PLUGIN_NAME} PRIVATE -nostdlib++ -l:libc++.a -l:libc++abi.a)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  PkgConfig::GTK
  thermion_dart
  EGL
  GL
)

# List of absolute paths to libraries that should be bundled with the plugin.
set(thermion_flutter_bundled_libraries
  ""
  PARENT_SCOPE
)
