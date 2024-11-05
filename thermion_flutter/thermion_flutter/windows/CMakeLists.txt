cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_flutter")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "thermion_flutter_plugin")

list(APPEND PLUGIN_SOURCES
  "thermion_flutter_plugin.cpp"
  "thermion_flutter_plugin.h"
  "flutter_d3d_texture.cpp"
)

add_subdirectory("rendering/vulkan")

add_library(${PLUGIN_NAME} SHARED
  "include/thermion_flutter/thermion_flutter_plugin_c_api.h"
  "thermion_flutter_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

include_directories(
  "${CMAKE_SOURCE_DIR}/../../../../thermion_dart/native/include/filament"
  "${CMAKE_SOURCE_DIR}/../../../../thermion_dart/native/include"
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  E:\\VulkanSDK\\1.3.296.0\\Include
)

target_link_libraries(${PLUGIN_NAME} PRIVATE 
 flutter
 flutter_wrapper_plugin 
 Shlwapi
 thermion_vulkan
)

# Copy thermion_egl library to the Flutter build directory
add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  $<TARGET_FILE:thermion_vulkan>
  $<TARGET_FILE_DIR:${PLUGIN_NAME}>
)

set(thermion_flutter_bundled_libraries
  ${runner_BINARY_DIR}/../../../native_assets/windows/thermion_dart.dll
  $<TARGET_FILE:thermion_vulkan>
  PARENT_SCOPE
)

