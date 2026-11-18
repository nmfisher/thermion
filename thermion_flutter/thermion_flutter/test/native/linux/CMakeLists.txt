cmake_minimum_required(VERSION 3.19)
project(thermion_linux_plugin_harness LANGUAGES C CXX)

# Host-side harness for the Linux plugin's texture lifecycle. Compiles
# linux/thermion_flutter_plugin.cc and linux/egl_texture.cc unmodified against
# stub Flutter/EGL/GL/producer headers (stubs/) backed by fakes (fakes/).
# Needs only GLib/GObject, so it runs on hosted CI without a GPU or display,
# and on macOS for local iteration.
#
#   cmake -S . -B build -DTHERMION_SANITIZER=thread   # or address, or none
#   cmake --build build && ctest --test-dir build --output-on-failure

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(THERMION_PLUGIN_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../linux"
    CACHE PATH "thermion_flutter/linux directory under test")
set(THERMION_DART_INCLUDE_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../thermion_dart/native/include"
    CACHE PATH "thermion_dart/native/include (for SurfaceExportInfo.h, Log.hpp)")
set(THERMION_SANITIZER "none" CACHE STRING "none, address or thread")
set_property(CACHE THERMION_SANITIZER PROPERTY STRINGS none address thread)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GLIB REQUIRED IMPORTED_TARGET glib-2.0 gobject-2.0)
find_package(Threads REQUIRED)

add_executable(linux_plugin_lifecycle_test
  tests/plugin_lifecycle_test.cc
  fakes/fake_flutter.cc
  fakes/fake_egl_gl.cc
  fakes/fake_producers.cc
  "${THERMION_PLUGIN_SOURCE_DIR}/thermion_flutter_plugin.cc"
  "${THERMION_PLUGIN_SOURCE_DIR}/egl_texture.cc"
)

# Stubs must win over the real thermion_dart headers of the same name
# (vulkan/linux/LinuxVulkanContext.h, vulkan/ExternalVulkanImage.h).
target_include_directories(linux_plugin_lifecycle_test PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/stubs"
  "${CMAKE_CURRENT_SOURCE_DIR}/fakes"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${THERMION_PLUGIN_SOURCE_DIR}"
  "${THERMION_DART_INCLUDE_DIR}"
)
target_compile_definitions(linux_plugin_lifecycle_test PRIVATE FLUTTER_PLUGIN_IMPL)
target_link_libraries(linux_plugin_lifecycle_test PRIVATE PkgConfig::GLIB Threads::Threads)

# The plugin is built against libc++ (linux/CMakeLists.txt). Match it: the
# plugin keeps a std::string inside a GObject instance struct, which GObject
# zero-fills without running constructors. That happens to be a valid empty
# string with libc++ but crashes with libstdc++.
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "Build the harness with clang++ and libc++, like the plugin.")
  endif()
  target_compile_options(linux_plugin_lifecycle_test PRIVATE -stdlib=libc++)
  target_link_options(linux_plugin_lifecycle_test PRIVATE -stdlib=libc++)
endif()

if(NOT THERMION_SANITIZER STREQUAL "none")
  target_compile_options(linux_plugin_lifecycle_test PRIVATE
    -fsanitize=${THERMION_SANITIZER} -fno-omit-frame-pointer -g -O1)
  target_link_options(linux_plugin_lifecycle_test PRIVATE
    -fsanitize=${THERMION_SANITIZER})
endif()
if(THERMION_SANITIZER STREQUAL "thread" AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  # GLib's Linux GMutex is futex-based and invisible to TSan.
  target_sources(linux_plugin_lifecycle_test PRIVATE fakes/tsan_glib_mutex.cc)
  target_link_libraries(linux_plugin_lifecycle_test PRIVATE ${CMAKE_DL_LIBS})
endif()

# One ctest per test case so a sanitizer abort in one case does not hide the
# others.
enable_testing()
file(STRINGS tests/plugin_lifecycle_test.cc _test_lines REGEX "^THERMION_TEST\\(")
foreach(_line IN LISTS _test_lines)
  string(REGEX REPLACE "^THERMION_TEST\\(([A-Za-z0-9_]+)\\).*" "\\1" _name "${_line}")
  add_test(NAME ${_name} COMMAND linux_plugin_lifecycle_test ${_name})
  # Destroyed texture shells are retained by design (see release_texture), so
  # LeakSanitizer reports are expected; fakes account for real resources.
  set_tests_properties(${_name} PROPERTIES
    ENVIRONMENT "ASAN_OPTIONS=detect_leaks=0;TSAN_OPTIONS=halt_on_error=1")
endforeach()
