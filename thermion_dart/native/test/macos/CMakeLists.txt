cmake_minimum_required(VERSION 3.15)
project(thermion_dart VERSION 1.0.0 LANGUAGES CXX C)

option(THERMION_ENABLE_RUNTIME_MATERIALS "Compile runtime material parser and compiler entry points" OFF)

add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>")

# Configuration variables
set(FILAMENT_VERSION "v1.77.2")
set(PACKAGE_NAME "thermion_dart")
set(PLATFORM "macos")

# Paths to actual native source/include (two levels up)
set(NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")

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
    "${NATIVE_ROOT}/src/*.cpp"
    "${NATIVE_ROOT}/src/scene/*.cpp"
)


# Exclude specific files
list(FILTER SOURCES EXCLUDE REGEX "CMakeLists.txt|main.cpp|windows|linux|d3d|build")

# Optional helper materials are compiled on demand by the Dart build hook;
# standalone native C++ tests build the slim library without embedded helpers.
set(RESOURCE_SOURCES)

# Dart API DL for port-based frame scheduling (hot restart safe)
set(DART_API_SOURCES
    "${NATIVE_ROOT}/include/dart/dart_api_dl.c"
)


# Create the shared library
add_library(thermion_dart SHARED
    ${SOURCES}
    ${RESOURCE_SOURCES}
    ${DART_API_SOURCES}
)

# Filament libraries path + headers, from the version-matched R2 artifact
# extracted by thermion_dart's build hook under .dart_tool/.
set(FILAMENT_LIB_DIR "" CACHE PATH "Filament artifact directory, including its pin hash suffix")
if(NOT FILAMENT_LIB_DIR)
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(FILAMENT_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../.dart_tool/thermion_dart/lib/${FILAMENT_VERSION}/macos/debug")
  else()
    set(FILAMENT_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../.dart_tool/thermion_dart/lib/${FILAMENT_VERSION}/macos/release")
  endif()
endif()
set(FILAMENT_INCLUDE_DIR "${FILAMENT_LIB_DIR}/include")

target_include_directories(thermion_dart PRIVATE
    "${NATIVE_ROOT}/include"
    "${FILAMENT_INCLUDE_DIR}"
)

# Set the output name of the library
set_target_properties(thermion_dart PROPERTIES
    OUTPUT_NAME "thermion_dart"
    PREFIX "lib"
    SUFFIX ".dylib"
)

# Link libraries
target_link_directories(thermion_dart PRIVATE ${FILAMENT_LIB_DIR})
if(THERMION_ENABLE_RUNTIME_MATERIALS)
    target_link_libraries(thermion_dart PRIVATE matp)
endif()
# Value-check macro: always pass 0 or 1.
target_compile_definitions(thermion_dart
    PRIVATE THERMION_ENABLE_RUNTIME_MATERIALS=$<BOOL:${THERMION_ENABLE_RUNTIME_MATERIALS}>)
target_link_libraries(thermion_dart PRIVATE
    filament
    backend
    filameshio
    filamat
    shaders
    utils
    filabridge
    gltfio_core
    gltfio
    filament-iblprefilter
    image
    tinyexr
    filaflat
    dracodec
    ibl
    ktxreader
    z
    stb
    uberzlib
    smol-v
    basis_transcoder
    uberarchive
    zstd
    geometry
    bluegl
    bluevk
)

# Debug-only libraries (matching build.dart conditional)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_link_libraries(thermion_dart PRIVATE
        matdbg
        fgviewer
    )
endif()

# macOS frameworks
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(CORE_VIDEO_FRAMEWORK CoreVideo)
find_library(COCOA_FRAMEWORK Cocoa)
find_library(METAL_FRAMEWORK Metal)
find_library(QUARTZ_CORE_FRAMEWORK QuartzCore)

target_link_libraries(thermion_dart PRIVATE
    ${FOUNDATION_FRAMEWORK}
    ${CORE_VIDEO_FRAMEWORK}
    ${COCOA_FRAMEWORK}
    ${METAL_FRAMEWORK}
    ${QUARTZ_CORE_FRAMEWORK}
    c++
)

# Install rules
install(TARGETS thermion_dart
    LIBRARY DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/build"
)
