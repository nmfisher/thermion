cmake_minimum_required(VERSION 3.19)
set(PROJECT_NAME "thermion_flutter")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "thermion_flutter_plugin")

list(APPEND PLUGIN_SOURCES
  "thermion_flutter_plugin.cpp"
  "thermion_flutter_plugin.h"
  "flutter_d3d_texture.cpp"
  "include/dart/dart_api_dl.c"
)

add_library(${PLUGIN_NAME} SHARED
  "include/thermion_flutter/thermion_flutter_plugin_c_api.h"
  "thermion_flutter_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

get_filename_component(GENERATED_HEADERS_CMAKE
  "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/generated_headers.cmake" ABSOLUTE)

# `generated_headers.cmake` is produced by `thermion_flutter`'s build hook
# (`hook/build.dart`) during `flutter assemble dart_build`, which runs AFTER
# cmake config completes (as a custom MSBuild step). CMake configure and the
# Dart build hooks therefore have no guaranteed execution order (#132): the
# file may be missing on a fresh checkout, or stale after a hook change. It
# is only a *fallback* — the authoritative Filament include dirs are
# resolved deterministically below from thermion_dart's root, and every
# entry taken from this file is validated to exist before use.
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

# --- Resolve thermion_dart include paths -----------------------------------
# Preference 1: parse the consuming app's package_config.json, which exists
#   after `flutter pub get` and before cmake configure, to find thermion_dart's
#   root URI.  This works on a first-pass build when the hook hasn't run yet.
# Preference 2: fall back to the monorepo layout relative to the REAL plugin
#   source directory (follows symlinks / junctions).

set(_TD_INCLUDE "")
set(_TD_VULKAN_WINDOWS "")

include("${CMAKE_CURRENT_SOURCE_DIR}/../cmake/filament_headers.cmake")
thermion_resolve_package_root(_td_root "${runner_BINARY_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")

if(_td_root)
  set(_TD_INCLUDE "${_td_root}/native/include")
  if(EXISTS "${_td_root}/native/include/vulkan/windows")
    set(_TD_VULKAN_WINDOWS "${_td_root}/native/include/vulkan/windows")
  endif()
endif()

# Declare the hook's future cache paths, including content-addressed pins.
# Globbing only existing directories leaves the first compile without headers.
# The version file lives inside the package, including hosted/pub-cache layouts.
set(_FILAMENT_HEADERS "")
if(_td_root)
  thermion_filament_headers(_FILAMENT_HEADERS "${_td_root}" "windows")
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
thermion_escape_for_generator(_TD_VULKAN_WINDOWS_GEN "${_TD_VULKAN_WINDOWS}")

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

# PUBLIC scope: thermion_flutter_plugin.cpp itself needs the Filament
# headers (Platform.h transitively pulls in `utils::io::ostream`, etc.)
# AND any consumer that includes thermion_flutter_plugin.h needs them
# too. The previous INTERFACE-only scope hid the headers from this
# target's own compile, so `error C3083: 'io': the symbol to the left
# of a '::' must be a type` triggered on Platform.h:99.
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  ${_FILAMENT_HEADERS_GEN}
  ${DART_PKG_HEADERS_GEN}
  "${_TD_INCLUDE_GEN}"
  "${_TD_VULKAN_WINDOWS_GEN}"
)

get_cmake_property(_variableNames VARIABLES)
list (SORT _variableNames)
foreach (_variableName ${_variableNames})
    message(STATUS "${_variableName}=${${_variableName}}")
endforeach()

target_link_directories(${PLUGIN_NAME} PRIVATE "${runner_BINARY_DIR}/../../../native_assets/windows/")

target_link_libraries(${PLUGIN_NAME} PRIVATE 
 flutter
 flutter_wrapper_plugin 
 Shlwapi
 thermion_dart
)

# Native-assets hooks download Filament during this target. Finish them before
# compiling any plugin source that includes the future header paths above.
add_dependencies(${PLUGIN_NAME} flutter_assemble)

set(thermion_flutter_bundled_libraries
  "${runner_BINARY_DIR}/../../../native_assets/windows/thermion_dart.dll"
  "${runner_BINARY_DIR}/../../../native_assets/windows/thermion_dart.lib"
  PARENT_SCOPE
)

add_definitions(-DTHERMION_WIN32_KHR_BUILD=1)


