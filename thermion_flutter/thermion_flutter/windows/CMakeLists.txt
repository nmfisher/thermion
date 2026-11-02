cmake_minimum_required(VERSION 3.14)
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

set(GENERATED_HEADERS_CMAKE "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/generated_headers.cmake")

# `generated_headers.cmake` is produced by `thermion_flutter`'s build hook
# (`hook/build.dart`) during `flutter assemble dart_build`, which runs AFTER
# cmake config completes (as a custom MSBuild step). CMake configure and the
# Dart build hooks therefore have no guaranteed execution order (#132): the
# file may be missing on a fresh checkout, or stale after a hook change. It
# is only a *fallback* — the authoritative Filament include dirs are
# resolved deterministically below from thermion_dart's root, and every
# entry taken from this file is validated to exist before use.
if(EXISTS "${GENERATED_HEADERS_CMAKE}")
  include("${GENERATED_HEADERS_CMAKE}")
else()
  message(STATUS
    "thermion_flutter: ${GENERATED_HEADERS_CMAKE} not yet present; "
    "resolving Filament headers deterministically instead.")
  set(DART_PKG_HEADERS "")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${GENERATED_HEADERS_CMAKE}")

# Drop entries that no longer exist on disk — a stale file from an older
# hook version lists pre-artifact paths (native/include/filament*) that
# were removed from the tree.
if(DART_PKG_HEADERS)
  foreach(_dir IN LISTS DART_PKG_HEADERS)
    if(NOT IS_DIRECTORY "${_dir}")
      message(WARNING
        "thermion_flutter: ignoring non-existent include dir from "
        "generated_headers.cmake (stale hook output?): ${_dir}")
      list(REMOVE_ITEM DART_PKG_HEADERS "${_dir}")
    endif()
  endforeach()
endif()

# --- Resolve thermion_dart include paths -----------------------------------
# Preference 1: parse the consuming app's package_config.json, which exists
#   after `flutter pub get` and before cmake configure, to find thermion_dart's
#   root URI.  This works on a first-pass build when the hook hasn't run yet.
# Preference 2: fall back to the monorepo layout relative to the REAL plugin
#   source directory (follows symlinks / junctions).

set(_TD_INCLUDE "")
set(_TD_VULKAN_WINDOWS "")

# Walk up from runner_BINARY_DIR to find the Flutter app root
# (the directory containing .dart_tool/package_config.json).
# runner_BINARY_DIR is the runner's output directory, always under the
# consuming Flutter app's build/ tree.  CMAKE_CURRENT_SOURCE_DIR may point
# to the real source (resolved junctions/symlinks) outside the app tree.
set(_PKG_CONFIG "")
set(_search_dir "${runner_BINARY_DIR}")
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

if(NOT _td_root)
  # Monorepo fallback – resolves the real source dir (follows symlinks/junctions)
  # then navigates to thermion_dart using the known repo layout.
  get_filename_component(_REAL_PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
  get_filename_component(_td_root
    "${_REAL_PLUGIN_DIR}/../../../thermion_dart" ABSOLUTE)
  if(NOT EXISTS "${_td_root}/native/include")
    set(_td_root "")
  else()
    message(STATUS "thermion_flutter: using monorepo fallback ${_td_root}")
  endif()
endif()

if(_td_root)
  set(_TD_INCLUDE "${_td_root}/native/include")
  if(EXISTS "${_td_root}/native/include/vulkan/windows")
    set(_TD_VULKAN_WINDOWS "${_td_root}/native/include/vulkan/windows")
  endif()
endif()

# --- Filament artifact headers (deterministic; #132) ------------------------
# Filament's C++ headers ship inside the same version-matched artifact the
# build hook downloads (thermion_dart/hook/build.dart -> getLibDir):
#   <thermion_dart>/.dart_tool/thermion_dart/lib/<version>/windows/<mode>/include
# Derive them here from the same inputs the hook itself uses — thermion_dart's
# root plus filament.version — so configure never depends on hook-written
# state. Headers are build-mode-independent (the hook's own cache repair
# relies on that), so any extracted release/debug dir serves any build mode.
set(_ARTIFACT_INCLUDES "")
if(_td_root)
  set(_version_dir "*")
  set(_version_file "${_td_root}/../filament.version")
  if(EXISTS "${_version_file}")
    file(READ "${_version_file}" _version_raw)
    string(STRIP "${_version_raw}" _version_raw)
    # Format "<repo-url> <version>"; the version is the last field (matches
    # _getFilamentVersion in thermion_dart/hook/build.dart).
    string(REGEX MATCH "[^ \t]+$" _version_dir "${_version_raw}")
  endif()
  file(GLOB _ARTIFACT_INCLUDES CONFIGURE_DEPENDS
    "${_td_root}/.dart_tool/thermion_dart/lib/${_version_dir}/windows/*/include")
endif()

# A Filament include dir is usable when it actually carries the headers the
# plugin needs; some published debug artifacts shipped an include/ tree
# without bluevk (the hook repairs those caches — see build.dart).
set(_FILAMENT_HEADERS "")
foreach(_dir IN LISTS _ARTIFACT_INCLUDES DART_PKG_HEADERS)
  if(IS_DIRECTORY "${_dir}" AND EXISTS "${_dir}/bluevk/BlueVK.h")
    list(FIND _FILAMENT_HEADERS "${_dir}" _dup)
    if(_dup EQUAL -1)
      list(APPEND _FILAMENT_HEADERS "${_dir}")
    endif()
  endif()
endforeach()

if(NOT _FILAMENT_HEADERS)
  if(NOT _td_root)
    message(FATAL_ERROR
      "thermion_flutter: could not resolve thermion_dart's root (neither "
      "package_config.json nor the monorepo fallback); cannot locate "
      "Filament headers.")
  endif()
  message(FATAL_ERROR
    "thermion_flutter: no Filament headers found under "
    "${_td_root}/.dart_tool/thermion_dart/lib/${_version_dir}/windows/*/include "
    "(version pinned by ${_td_root}/../filament.version), and "
    "generated_headers.cmake provided no usable entry either. The artifact is "
    "downloaded by thermion_dart's build hook — on a clean machine the first "
    "build fetches it; rerun once that has completed.")
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
  ${_FILAMENT_HEADERS}
  ${DART_PKG_HEADERS}
  "${_TD_INCLUDE}"
  "${_TD_VULKAN_WINDOWS}"
)

get_cmake_property(_variableNames VARIABLES)
list (SORT _variableNames)
foreach (_variableName ${_variableNames})
    message(STATUS "${_variableName}=${${_variableName}}")
endforeach()

target_link_directories(${PLUGIN_NAME} PRIVATE ${runner_BINARY_DIR}/../../../native_assets/windows/)

target_link_libraries(${PLUGIN_NAME} PRIVATE 
 flutter
 flutter_wrapper_plugin 
 Shlwapi
 thermion_dart
)

set(thermion_flutter_bundled_libraries
  ${runner_BINARY_DIR}/../../../native_assets/windows/thermion_dart.dll
  ${runner_BINARY_DIR}/../../../native_assets/windows/thermion_dart.lib
  PARENT_SCOPE
)

add_definitions(-DTHERMION_WIN32_KHR_BUILD=1)


