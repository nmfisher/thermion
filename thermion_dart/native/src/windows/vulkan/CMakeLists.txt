cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_vulkan")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
set(BUILD_SHARED_LIBS TRUE)
set(CMAKE_ENABLE_EXPORTS TRUE)

add_definitions(-DWIN32_LEAN_AND_MEAN)

add_compile_options(/FS)
# Add Windows-specific compile definitions
add_definitions(-DWIN32)
add_definitions(-D_WINDOWS)

# Ensure UNICODE is defined
add_definitions(-DUNICODE)
add_definitions(-D_UNICODE)

add_library(${PROJECT_NAME} SHARED
  "d3d_context.cpp"
  "vulkan_context.cpp"
  "utils.cpp"
  "d3d_texture.cpp"
  "vulkan_texture.cpp"
  "vulkan_platform.cpp"
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_20)
include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../include/windows/vulkan"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../include/filament/"
  "${CMAKE_CURRENT_SOURCE_DIR}/"
)
target_link_directories(${PROJECT_NAME} PRIVATE
    "C:\\Users\\nickh\\Documents\\thermion\\thermion_dart\\.dart_tool\\thermion_dart\\lib\\v1.58.0\\windows\\debug"
)

target_link_libraries(${PROJECT_NAME} PRIVATE 
 Shlwapi
 dxgi
 d3d11
 bluevk
 vulkan-1
)

add_executable(${PROJECT_NAME}_test
  "main.cpp"
)

target_compile_features(${PROJECT_NAME}_test PUBLIC cxx_std_20)

target_link_directories(${PROJECT_NAME}_test PRIVATE
    "C:\\Users\\nickh\\Documents\\thermion\\thermion_dart\\.dart_tool\\thermion_dart\\lib\\v1.58.0\\windows\\debug"
)

target_link_libraries(${PROJECT_NAME}_test PRIVATE
  ${PROJECT_NAME}
)

add_dependencies(${PROJECT_NAME}_test ${PROJECT_NAME})