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
# (`hook/build.dart`) during `flutter assemble dart_build`, which runs as a
# custom build step inside MSBuild AFTER cmake config completes. On a fresh
# checkout the file does not yet exist, so an unconditional `include()`
# would error out (`include could not find requested file`) and abort cmake
# — preventing the dart_build step from ever running and leaving a fresh
# `flutter run` / `flutter build windows` permanently stuck unless the user
# knows to fire the hook out of band first (e.g. via `flutter test`).
#
# Include conditionally and register the file as a configure dependency so
# that, once dart_build produces it, the next build invocation
# auto-regenerates cmake and the plugin compile picks up the correct
# `DART_PKG_HEADERS`. On a clean checkout this means a two-pass build:
# first pass populates the file (plugin compile fails because
# DART_PKG_HEADERS is empty), second pass succeeds.
if(EXISTS "${GENERATED_HEADERS_CMAKE}")
  include("${GENERATED_HEADERS_CMAKE}")
else()
  message(STATUS
    "thermion_flutter: ${GENERATED_HEADERS_CMAKE} not yet present. "
    "Cmake will continue with an empty DART_PKG_HEADERS so that "
    "`flutter assemble dart_build` can run and produce the file; "
    "the next build will pick it up automatically.")
  set(DART_PKG_HEADERS "")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${GENERATED_HEADERS_CMAKE}")

# PUBLIC scope: thermion_flutter_plugin.cpp itself needs the Filament
# headers (Platform.h transitively pulls in `utils::io::ostream`, etc.)
# AND any consumer that includes thermion_flutter_plugin.h needs them
# too. The previous INTERFACE-only scope hid the headers from this
# target's own compile, so `error C3083: 'io': the symbol to the left
# of a '::' must be a type` triggered on Platform.h:99.
#
# The second `include_directories(${PLUGIN_NAME} INTERFACE ...)` call
# below is also invalid CMake syntax — `include_directories` takes
# only paths, no target or scope keyword — so it silently does
# nothing. Removed.
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  ${DART_PKG_HEADERS}
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


