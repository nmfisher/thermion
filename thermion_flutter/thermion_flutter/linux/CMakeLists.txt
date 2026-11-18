cmake_minimum_required(VERSION 3.19)
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

# thermion_dart's build hook writes DART_PKG_HEADERS (the extracted Filament
# artifact `include/` plus Thermion's own `native/include`) to
# generated_headers.cmake. CMake configure and the Dart build hooks have no
# guaranteed execution order (#132): the file may be missing on a first
# build, or stale after a hook change. It is only a *fallback* — the
# authoritative Filament include dirs are resolved deterministically below
# from thermion_dart's root, and every entry taken from this file is
# validated to exist before use.
get_filename_component(GENERATED_HEADERS_CMAKE
  "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/generated_headers.cmake" ABSOLUTE)
if(EXISTS "${GENERATED_HEADERS_CMAKE}")
  # include() automatically registers the file as a configure dependency.
  include("${GENERATED_HEADERS_CMAKE}")
else()
  message(STATUS
    "thermion_flutter: ${GENERATED_HEADERS_CMAKE} not yet present; "
    "resolving Filament headers deterministically instead.")
  set(DART_PKG_HEADERS "")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${GENERATED_HEADERS_CMAKE}")
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

include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/filament_headers.cmake")
thermion_resolve_package_root(_td_root "${CMAKE_BINARY_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")

if(_td_root)
  set(_TD_INCLUDE "${_td_root}/native/include")
  if(EXISTS "${_td_root}/native/include/vulkan/linux")
    set(_TD_VULKAN_LINUX "${_td_root}/native/include/vulkan/linux")
  endif()
  if(EXISTS "${_td_root}/native/include/opengl/linux")
    set(_TD_OPENGL_LINUX "${_td_root}/native/include/opengl/linux")
  endif()
endif()

# Declare the hook's future cache paths, including content-addressed pins and
# Linux arm64's nested directory layout. Globbing only existing directories
# leaves the first compile without headers on a clean cache.
set(_FILAMENT_HEADERS "")
if(_td_root)
  thermion_linux_filament_platform(_filament_platform)
  thermion_filament_headers(_FILAMENT_HEADERS "${_td_root}" "${_filament_platform}")
endif()

thermion_filter_generated_headers(DART_PKG_HEADERS "${_FILAMENT_HEADERS}")

# MSBuild unescapes %XX in project metadata; escape literal '%' in every
# path handed to the generator (see thermion_escape_for_generator). The
# unescaped lists above stay intact for CMake's own existence checks.
set(_FILAMENT_HEADERS_GEN "")
foreach(_dir IN LISTS _FILAMENT_HEADERS)
  thermion_escape_for_generator(_dir_gen "${_dir}")
  list(APPEND _FILAMENT_HEADERS_GEN "${_dir_gen}")
endforeach()
set(DART_PKG_HEADERS_GEN "")
foreach(_dir IN LISTS DART_PKG_HEADERS)
  thermion_escape_for_generator(_dir_gen "${_dir}")
  list(APPEND DART_PKG_HEADERS_GEN "${_dir_gen}")
endforeach()
thermion_escape_for_generator(_TD_INCLUDE_GEN "${_TD_INCLUDE}")
thermion_escape_for_generator(_TD_VULKAN_LINUX_GEN "${_TD_VULKAN_LINUX}")
thermion_escape_for_generator(_TD_OPENGL_LINUX_GEN "${_TD_OPENGL_LINUX}")

# Retain existing hook metadata as a fallback, after the current pin's paths.
foreach(_dir IN LISTS DART_PKG_HEADERS)
  if(IS_DIRECTORY "${_dir}" AND EXISTS "${_dir}/bluevk/BlueVK.h")
    list(FIND _FILAMENT_HEADERS "${_dir}" _dup)
    if(_dup EQUAL -1)
      list(APPEND _FILAMENT_HEADERS "${_dir}")
    endif()
  endif()
endforeach()

if(NOT _FILAMENT_HEADERS)
  message(FATAL_ERROR
    "thermion_flutter: could not resolve thermion_dart's root (neither "
    "package_config.json nor the monorepo fallback); cannot locate "
    "Filament headers.")
endif()
message(STATUS "thermion_flutter: Filament headers: ${_FILAMENT_HEADERS}")

target_include_directories(${PLUGIN_NAME} PRIVATE
  ${_FILAMENT_HEADERS_GEN}
  ${DART_PKG_HEADERS_GEN}
  "${_TD_INCLUDE_GEN}"
  "${_TD_VULKAN_LINUX_GEN}"
  "${_TD_OPENGL_LINUX_GEN}"
)
target_link_directories(${PLUGIN_NAME} PRIVATE "${NATIVE_ASSETS_DIR}")

# The native build links thermion_dart.so with -Wl,-z,defs, so unresolved
# symbols fail while producing the library. Keep the final executable link
# strict as well; --allow-shlib-undefined would hide regressions here.

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

# Native-assets hooks download Filament and build libthermion_dart.so during
# flutter_assemble. Finish them before compiling or linking the plugin.
add_dependencies(${PLUGIN_NAME} flutter_assemble)

# List of absolute paths to libraries that should be bundled with the plugin.
set(thermion_flutter_bundled_libraries
  ""
  PARENT_SCOPE
)
