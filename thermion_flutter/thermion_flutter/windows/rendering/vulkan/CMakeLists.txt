cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_vulkan")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
set(BUILD_SHARED_LIBS TRUE)
set(CMAKE_ENABLE_EXPORTS TRUE)

add_definitions(-DVK_STATIC_DISPATCH)
add_definitions(-DWIN32_LEAN_AND_MEAN)

add_library(${PROJECT_NAME} SHARED
  "d3d_texture.cpp"
  "vulkan_context.cpp"
  "utils.cpp"
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_20)
include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include"
  "${CMAKE_CURRENT_SOURCE_DIR}/"
  E:\\VulkanSDK\\1.3.296.0\\Include
)
target_link_directories(${PROJECT_NAME} PRIVATE
    E:\\VulkanSDK\\1.3.296.0\\Lib
)

target_link_libraries(${PROJECT_NAME} PRIVATE 
 Shlwapi
 dxgi
 d3d11
 vulkan-1
)

add_executable(${PROJECT_NAME}_test
  "main.cpp"
)

target_include_directories(${PROJECT_NAME}_test PRIVATE 
    E:\\VulkanSDK\\1.3.296.0\\Include
)
target_link_directories(${PROJECT_NAME}_test PRIVATE
    E:\\VulkanSDK\\1.3.296.0\\Lib
)
target_link_libraries(${PROJECT_NAME}_test PRIVATE
  ${PROJECT_NAME}
  vulkan-1
)

add_dependencies(${PROJECT_NAME}_test ${PROJECT_NAME})