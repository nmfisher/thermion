cmake_minimum_required(VERSION 3.15)
project(thermion_dart VERSION 1.0.0 LANGUAGES CXX C)

# Configuration variables
set(FILAMENT_VERSION "v1.58.0")
set(PACKAGE_NAME "thermion_dart")
set(PLATFORM "macos")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set macOS specific options
set(CMAKE_OSX_DEPLOYMENT_TARGET 13.0)
set(CMAKE_MACOSX_RPATH ON)

# Debug build by default
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif()

# Enable tracing
add_definitions(-DENABLE_TRACING=1)

# Locate source files
file(GLOB_RECURSE SOURCES 
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/scene/*.cpp"
)


# Exclude specific files
list(FILTER SOURCES EXCLUDE REGEX "CMakeLists.txt|main.cpp|windows")

# Material and resource sources
set(MATERIAL_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/include/material/unlit_fixed_size.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/material/image.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/material/grid.c"
)

set_source_files_properties(${MATERIAL_SOURCES} PROPERTIES LANGUAGE CXX)

set(RESOURCE_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/include/resources/translation_gizmo_glb.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/resources/rotation_gizmo_glb.c"
)

set_source_files_properties(${RESOURCE_SOURCES} PROPERTIES LANGUAGE CXX)


# Create the shared library
add_library(thermion_dart SHARED 
    ${SOURCES} 
    ${MATERIAL_SOURCES} 
    ${RESOURCE_SOURCES}
)

# Include directories
target_include_directories(thermion_dart PRIVATE 
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/filament"
)

# Set the output name of the library
set_target_properties(thermion_dart PROPERTIES 
    OUTPUT_NAME "thermion_dart"
    PREFIX "lib"
    SUFFIX ".dylib"
)

# Filament libraries path
set(FILAMENT_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/thermion_dart/lib/${FILAMENT_VERSION}/macos/debug")

# Link libraries
target_link_directories(thermion_dart PRIVATE ${FILAMENT_LIB_DIR})
target_link_libraries(thermion_dart PRIVATE
    filament
    backend
    filameshio
    viewer
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
    fgviewer
    bluegl
    bluevk
)

# macOS frameworks
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(CORE_VIDEO_FRAMEWORK CoreVideo)
find_library(COCOA_FRAMEWORK Cocoa)
find_library(METAL_FRAMEWORK Metal)

target_link_libraries(thermion_dart PRIVATE
    ${FOUNDATION_FRAMEWORK}
    ${CORE_VIDEO_FRAMEWORK}
    ${COCOA_FRAMEWORK}
    ${METAL_FRAMEWORK}
)

# Install rules
install(TARGETS thermion_dart
    LIBRARY DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/build"
)
