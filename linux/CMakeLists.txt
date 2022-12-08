# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "polyvox_filament")
project(${PROJECT_NAME})

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -fPIC -Wno-unused-variable -Wno-unused-function")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -Wno-unused-variable")

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "polyvox_filament_plugin")

link_directories("${CMAKE_CURRENT_SOURCE_DIR}/lib") 

add_library(FILAMENT_SHADERS SHARED 
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/image_material.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/unlitopaque.c"  
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
#
# Any new source files that you add to the plugin should be added here.
add_library(${PLUGIN_NAME} SHARED
  "polyvox_filament_plugin.cc"
  "filament_texture.cc"
  "filament_pb_texture.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/SceneAssetLoader.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/SceneAsset.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/FilamentViewer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/PolyvoxFilamentApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/StreamBufferAdapter.cpp"
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(../example/linux)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)


target_link_libraries(${PLUGIN_NAME} PRIVATE
  FILAMENT_SHADERS
  geometry 
  filament 
  backend 
  geometry 
  filameshio 
  viewer 
  filamat 
  utils 
  filabridge 
  gltfio_core 
  filament-iblprefilter 
  image 
  camutils 
  filaflat 
  dracodec 
  ibl 
  ktxreader 
  image
  imageio
  tinyexr
  stb  
  EGL 
  bluevk 
  vkshaders 
  bluegl 
  uberzlib 
  smol-v 
  uberarchive 
  meshoptimizer
  mathio
  -l:libmath.a
  geometry 
)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(polyvox_filament_bundled_libraries
  ""
  PARENT_SCOPE
)
