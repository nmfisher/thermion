cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "flutter_filament")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "flutter_filament_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "flutter_filament_plugin.cpp"
  "flutter_filament_plugin.h"
)

set(USE_ANGLE FALSE)
set(WGL_USE_BACKING_WINDOW TRUE)

if(USE_ANGLE)
  add_compile_definitions(USE_ANGLE)
  list(APPEND PLUGIN_SOURCES    "flutter_angle_texture.cpp"   "egl_context.cpp"   )
else() 
  if(WGL_USE_BACKING_WINDOW)
    add_compile_definitions(WGL_USE_BACKING_WINDOW)
  endif()
  list(APPEND PLUGIN_SOURCES "wgl_context.cpp" "opengl_texture_buffer.cpp" "backing_window.cpp")
endif()

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/flutter_filament/flutter_filament_plugin_c_api.h"
  "flutter_filament_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
  "include/material/image.c"
)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

include_directories(
  "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/include/filament"
  "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/include"
)

if(USE_ANGLE)
  list(APPEND GL_LIBS
    EGL
    GLESv2
  )
  set(ANGLE_OR_OPENGL_DIR angle)
  add_library(EGL SHARED IMPORTED)
  set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mdd/libEGL.dll.lib")
  set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mt/angle/libEGL.dll.lib")
  set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mt/angle/libEGL.dll.lib")
  add_library(GLESv2 SHARED IMPORTED)
  set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mdd/libGLESv2.dll.lib")
  set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mt/angle/libGLESv2.dll.lib")
  set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mt/angle/libGLESv2.dll.lib")
else()
  list(APPEND GL_LIBS
    bluegl
    opengl32
    dwmapi
    comctl32
  )
  set(ANGLE_OR_OPENGL_DIR opengl)
  add_library(bluegl SHARED IMPORTED)
  set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mdd/bluegl.lib")
  set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mt/bluegl.lib")
  set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_SOURCE_DIR}/../../../../dart_filament/native/lib/windows/x86_64/mt/bluegl.lib")
endif()

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${PLUGIN_NAME} PRIVATE 
 flutter
 flutter_wrapper_plugin 
 Shlwapi
 ${GL_LIBS}
)

# List of absolute paths to libraries that should be bundled with the plugin
if(USE_ANGLE)
set(flutter_filament_bundled_libraries
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/angle/libEGL.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/angle/libGLESv2.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/libc++.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/third_party_abseil-cpp_absl.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/third_party_zlib.dll
  PARENT_SCOPE
)
endif()

