cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "thermion_vulkan")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

add_library(${PROJECT_NAME} SHARED
  "../../src/vulkan/BaseVulkanTexture.cpp"
  "../../src/vulkan/VulkanUtils.cpp"
  "../../src/vulkan/linux/LinuxVulkanTexture.cpp"
  "../../src/vulkan/linux/LinuxVulkanContext.cpp"
  "../../src/vulkan/linux/LinuxVulkanUtils.cpp"
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_20)

# Set Filament version, library path, and headers (from the version-matched
# R2 artifact extracted by thermion_dart's build hook under .dart_tool/).
set(FILAMENT_VERSION "v1.74.0")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(FILAMENT_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../.dart_tool/thermion_dart/lib/${FILAMENT_VERSION}/linux/debug")
else()
  set(FILAMENT_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../.dart_tool/thermion_dart/lib/${FILAMENT_VERSION}/linux/release")
endif()

target_include_directories(${PROJECT_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include/vulkan"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include/vulkan/linux"
  "${FILAMENT_LIB_DIR}/include"
)

target_link_directories(${PROJECT_NAME} PRIVATE ${FILAMENT_LIB_DIR})

target_link_libraries(${PROJECT_NAME} PRIVATE
  bluevk
  vulkan
  backend
  filament
  utils
  dl
  pthread
)

add_executable(${PROJECT_NAME}_test
  "main.cpp"
)

# Find SDL2
find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED sdl2)

target_compile_features(${PROJECT_NAME}_test PUBLIC cxx_std_20)
target_include_directories(${PROJECT_NAME}_test PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include/vulkan"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../include/vulkan/linux"
  "${FILAMENT_LIB_DIR}/include"
  ${SDL2_INCLUDE_DIRS}
)

target_link_libraries(${PROJECT_NAME}_test PRIVATE
  ${PROJECT_NAME}
  ${SDL2_LIBRARIES}
  filament
  backend
  filamat
  meshoptimizer
  mikktspace
  geometry
  utils
  filabridge
  gltfio_core
  gltfio
  filament-iblprefilter
  image
  imageio
  tinyexr
  filaflat
  dracodec
  ibl
  ktxreader
  png
  z
  stb
  uberzlib
  smol-v
  uberarchive
  zstd
  basis_transcoder
  matdbg
  bluegl
  bluevk
  vulkan
  c++
  c++abi
  dl
  pthread
)

target_link_directories(${PROJECT_NAME}_test PRIVATE ${FILAMENT_LIB_DIR})

add_dependencies(${PROJECT_NAME}_test ${PROJECT_NAME})
