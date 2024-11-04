cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_egl")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
set(BUILD_SHARED_LIBS TRUE)
set(CMAKE_ENABLE_EXPORTS TRUE)

add_library(${PROJECT_NAME} SHARED
  "egl_context.cpp"
  "egl_texture.cpp"
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_20)
include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include"
)

add_library(EGL SHARED IMPORTED)
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_DEBUG "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_PROFILE "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_RELEASE "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_MINSIZEREL "E:\\angle\\libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_RELWITHDEBINFO "E:\\angle\\libEGL.dll.lib")
add_library(GLESv2 SHARED IMPORTED)
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_DEBUG "E:\\angle\\libGLESv2.dll.lib")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_PROFILE "E:\\angle\\libGLESv2.dll.lib")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_RELEASE "E:\\angle\\libGLESv2.dll")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_MINSIZEREL "E:\\angle\\libGLESv2.dll")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_RELWITHDEBINFO "E:\\angle\\libGLESv2.dll")

target_link_libraries(${PROJECT_NAME} PRIVATE 
 Shlwapi
 EGL 
 GLESv2
 dxgi
  d3d11
)

