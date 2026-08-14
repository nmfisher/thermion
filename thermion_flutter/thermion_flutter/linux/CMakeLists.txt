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

# Filament C++ headers are sourced from the version-matched R2 artifact via
# thermion_dart's build hook, which writes DART_PKG_HEADERS (the extracted
# artifact `include/` plus Thermion's own `native/include`) to
# generated_headers.cmake. See thermion_flutter/hook/build.dart.
set(GENERATED_HEADERS_CMAKE "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/generated_headers.cmake")
if(EXISTS "${GENERATED_HEADERS_CMAKE}")
  include("${GENERATED_HEADERS_CMAKE}")
else()
  message(STATUS
    "thermion_flutter: ${GENERATED_HEADERS_CMAKE} not yet present; "
    "DART_PKG_HEADERS is empty. The dart_build step will produce it and the "
    "next build will pick it up automatically.")
  set(DART_PKG_HEADERS "")
endif()

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
set(_TD_VULKAN_LINUX "")
set(_TD_OPENGL_LINUX "")

# Walk up from CMAKE_BINARY_DIR to find the Flutter app root
# (the directory containing .dart_tool/package_config.json).
# CMAKE_BINARY_DIR is always under the consuming Flutter app's build/ tree.
# CMAKE_CURRENT_SOURCE_DIR may point to the real source (resolved symlinks)
# outside the app tree.
set(_PKG_CONFIG "")
set(_search_dir "${CMAKE_BINARY_DIR}")
foreach(_i RANGE 1 15)
  if(EXISTS "${_search_dir}/.dart_tool/package_config.json")
    set(_PKG_CONFIG "${_search_dir}/.dart_tool/package_config.json")
    message(STATUS "thermion_flutter: found package_config at ${_PKG_CONFIG}")
    break()
  endif()
  get_filename_component(_search_dir "${_search_dir}" DIRECTORY)
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
        # rootUri may be a file:/// URI (e.g. file:///D:/path on Windows,
        # file:///home on Linux) or a relative path like "../../thermion_dart".
        # Strip file:/// (3 slashes) first, then file:// (2 slashes) as fallback.
        string(REGEX REPLACE "^file:///" "" _td_root "${_td_rootUri}")
        string(REGEX REPLACE "^file://" "" _td_root "${_td_root}")
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
  ${DART_PKG_HEADERS}
  "${_TD_INCLUDE}"
  "${_TD_VULKAN_LINUX}"
  "${_TD_OPENGL_LINUX}"
)
target_link_directories(${PLUGIN_NAME} PRIVATE "${NATIVE_ASSETS_DIR}")

# Historically thermion_dart.so carried unresolved basisu/draco encoder
# symbols (pulled in by --whole-archive on filamat in the build hook), so
# this plugin propagated --allow-shlib-undefined to the executable. The
# hook no longer uses --whole-archive (see docs/optional-libs-proposal.md)
# and ldd -r reports zero unresolved symbols, so the workaround is gone.
# If a future change reintroduces unresolved symbols, restore:
#   set_property(TARGET ${PLUGIN_NAME} APPEND PROPERTY
#     INTERFACE_LINK_OPTIONS "-Wl,--allow-shlib-undefined")

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
