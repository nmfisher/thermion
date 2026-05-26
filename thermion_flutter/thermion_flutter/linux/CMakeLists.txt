cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_flutter")
project(${PROJECT_NAME} LANGUAGES C CXX)
set(PLUGIN_NAME "thermion_flutter_plugin")

add_library(${PLUGIN_NAME} SHARED
  "thermion_flutter_plugin.cc"
  "egl_texture.cc"
)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "/usr/include/gtk-3.0"
  )

# thermion_dart native-assets output
# Flutter places native-assets at: <project>/build/native_assets/linux/
# CMake build dir is: <project>/build/linux/x64/{release,debug}/
# So relative path from CMAKE_BINARY_DIR is ../../../native_assets/linux/
set(NATIVE_ASSETS_DIR "${CMAKE_BINARY_DIR}/../../../native_assets/linux")

target_include_directories(${PLUGIN_NAME} PRIVATE "${NATIVE_ASSETS_DIR}")

# --- Resolve thermion_dart include paths -----------------------------------
# Preference 1: parse the consuming app's package_config.json, which exists
#   after `flutter pub get` and before cmake configure, to find thermion_dart's
#   root URI.
# Preference 2: fall back to the monorepo layout relative to the REAL plugin
#   source directory (follows symlinks).

set(_TD_INCLUDE "")
set(_TD_FILAMENT_INCLUDE "")
set(_TD_FILAMENT_DEBUG "")
set(_TD_FILAMENT_RELEASE "")
set(_TD_VULKAN_LINUX "")
set(_TD_OPENGL_LINUX "")

# Walk up from CMAKE_BINARY_DIR to find the Flutter app root
# (the directory containing .dart_tool/package_config.json).
# Avoids hardcoding a specific nesting depth for the build directory.
set(_PKG_CONFIG "")
set(_search_dir "${CMAKE_BINARY_DIR}")
foreach(_i RANGE 1 10)
  if(EXISTS "${_search_dir}/.dart_tool/package_config.json")
    set(_PKG_CONFIG "${_search_dir}/.dart_tool/package_config.json")
    break()
  endif()
  get_filename_component(_parent "${_search_dir}/.." ABSOLUTE)
  if(_parent STREQUAL _search_dir)
    break()
  endif()
  set(_search_dir "${_parent}")
endforeach()

if(_PKG_CONFIG)
  file(READ "${_PKG_CONFIG}" _pkg_json)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.19")
    string(JSON _pkg_len ERROR_VARIABLE _json_err LENGTH "${_pkg_json}" packages)
    if(NOT _json_err AND _pkg_len GREATER 0)
      math(EXPR _pkg_end "${_pkg_len} - 1")
      set(_td_rootUri "")
      foreach(_idx RANGE 0 ${_pkg_end})
        string(JSON _pkg_name ERROR_VARIABLE _json_err GET "${_pkg_json}" packages ${_idx} name)
        if(_json_err)
          continue()
        endif()
        if(_pkg_name STREQUAL "thermion_dart")
          string(JSON _td_rootUri ERROR_VARIABLE _json_err GET "${_pkg_json}" packages ${_idx} rootUri)
          break()
        endif()
      endforeach()

      if(_td_rootUri)
        string(REGEX REPLACE "^file://" "" _td_root "${_td_rootUri}")
        if(NOT IS_ABSOLUTE "${_td_root}")
          get_filename_component(_pkg_dir "${_PKG_CONFIG}" DIRECTORY)
          get_filename_component(_td_root "${_pkg_dir}/${_td_root}" ABSOLUTE)
        endif()
        message(STATUS "thermion_flutter: resolved thermion_dart to ${_td_root}")
      endif()
    endif()
  endif()
endif()

if(_td_root)
  set(_TD_INCLUDE "${_td_root}/native/include")
  set(_TD_FILAMENT_INCLUDE "${_td_root}/native/include/filament")
  if(EXISTS "${_td_root}/native/include/filament/debug")
    set(_TD_FILAMENT_DEBUG "${_td_root}/native/include/filament/debug")
  endif()
  if(EXISTS "${_td_root}/native/include/filament/release")
    set(_TD_FILAMENT_RELEASE "${_td_root}/native/include/filament/release")
  endif()
  if(EXISTS "${_td_root}/native/include/vulkan/linux")
    set(_TD_VULKAN_LINUX "${_td_root}/native/include/vulkan/linux")
  endif()
  if(EXISTS "${_td_root}/native/include/opengl/linux")
    set(_TD_OPENGL_LINUX "${_td_root}/native/include/opengl/linux")
  endif()
else()
  get_filename_component(_REAL_PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
  get_filename_component(_BASE
    "${_REAL_PLUGIN_DIR}/../../../thermion_dart/native/include" ABSOLUTE)
  if(EXISTS "${_BASE}")
    set(_TD_INCLUDE "${_BASE}")
    set(_TD_FILAMENT_INCLUDE "${_BASE}/filament")
    if(EXISTS "${_BASE}/filament/debug")
      set(_TD_FILAMENT_DEBUG "${_BASE}/filament/debug")
    endif()
    if(EXISTS "${_BASE}/filament/release")
      set(_TD_FILAMENT_RELEASE "${_BASE}/filament/release")
    endif()
    if(EXISTS "${_BASE}/vulkan/linux")
      set(_TD_VULKAN_LINUX "${_BASE}/vulkan/linux")
    endif()
    if(EXISTS "${_BASE}/opengl/linux")
      set(_TD_OPENGL_LINUX "${_BASE}/opengl/linux")
    endif()
    message(STATUS "thermion_flutter: using monorepo fallback ${_BASE}")
  endif()
endif()

target_include_directories(${PLUGIN_NAME} PRIVATE
  "${_TD_INCLUDE}"
  "${_TD_FILAMENT_INCLUDE}"
  "$<$<CONFIG:Debug>:${_TD_FILAMENT_DEBUG}>"
  "$<$<CONFIG:Release>:${_TD_FILAMENT_RELEASE}>"
  "$<$<CONFIG:RelWithDebInfo>:${_TD_FILAMENT_RELEASE}>"
  "$<$<CONFIG:MinSizeRel>:${_TD_FILAMENT_RELEASE}>"
  "${_TD_VULKAN_LINUX}"
  "${_TD_OPENGL_LINUX}"
)
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
  gbm
)

# List of absolute paths to libraries that should be bundled with the plugin.
set(thermion_flutter_bundled_libraries
  ""
  PARENT_SCOPE
)
