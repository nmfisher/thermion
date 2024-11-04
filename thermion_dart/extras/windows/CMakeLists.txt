cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_windows")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

add_compile_definitions(WGL_USE_BACKING_WINDOW)
add_compile_definitions(UNICODE)

add_library(${PROJECT_NAME} SHARED
  "thermion_window.cpp"
)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_20)
target_include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${CMAKE_SOURCE_DIR}/../../../../thermion_dart/native/include/filament"
  "${CMAKE_SOURCE_DIR}/../../../../thermion_dart/native/include"
  "${CMAKE_SOURCE_DIR}/../../../../thermion_flutter/thermion_flutter/windows"
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${PROJECT_NAME} PRIVATE 
 Shlwapi
 opengl32
 dwmapi
 comctl32
)

