cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "polyvox_filament")
project(${PROJECT_NAME} LANGUAGES C CXX)

cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "polyvox_filament_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "polyvox_filament_plugin.cpp"
  "polyvox_filament_plugin.h"
  "PlatformAngle.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/AssetManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/FilamentViewer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/PolyvoxFilamentApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/StreamBufferAdapter.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/TimeIt.cpp"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/polyvox_filament/polyvox_filament_plugin_c_api.h"
  "polyvox_filament_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/image.c"
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
 
add_library(EGL SHARED IMPORTED)
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libEGL.dll.lib")
set_property(TARGET EGL PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libEGL.dll.lib")
add_library(GLESv2 SHARED IMPORTED)
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/libGLESv2.dll.lib")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libGLESv2.dll.lib")
set_property(TARGET GLESv2 PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libGLESv2.dll.lib")
# add_library(d3d_compiler SHARED IMPORTED)
# set_property(TARGET d3d_compiler PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/${CMAKE_BUILD_TYPE_INIT}/d3dcompiler_47.dll")
# set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/bluegl.lib")
# set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/bluegl.lib")
# set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/bluegl.lib")

add_library(geometry SHARED IMPORTED)
set_property(TARGET geometry PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/geometry.lib")
set_property(TARGET geometry PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/geometry.lib")
set_property(TARGET geometry PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/geometry.lib")

add_library(filament SHARED IMPORTED)
set_property(TARGET filament PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/filament.lib")
set_property(TARGET filament PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filament.lib")
set_property(TARGET filament PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filament.lib")

add_library(backend SHARED IMPORTED)
set_property(TARGET backend PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/backend.lib")
set_property(TARGET backend PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/backend.lib")
set_property(TARGET backend PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/backend.lib")

add_library(filameshio SHARED IMPORTED)
set_property(TARGET filameshio PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/filameshio.lib")
set_property(TARGET filameshio PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filameshio.lib")
set_property(TARGET filameshio PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filameshio.lib")

add_library(filamat SHARED IMPORTED)
set_property(TARGET filamat PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/filamat.lib")
set_property(TARGET filamat  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filamat.lib")
set_property(TARGET filamat  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filamat.lib")

add_library(utils SHARED IMPORTED)
set_property(TARGET utils PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/utils.lib")
set_property(TARGET utils PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/utils.lib")
set_property(TARGET utils PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/utils.lib")

add_library(filabridge SHARED IMPORTED)
set_property(TARGET filabridge PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/filabridge.lib")
set_property(TARGET filabridge PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filabridge.lib")
set_property(TARGET filabridge PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filabridge.lib")

add_library(gltfio SHARED IMPORTED)
set_property(TARGET gltfio PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/gltfio.lib")
set_property(TARGET gltfio PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/gltfio.lib")
set_property(TARGET gltfio PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/gltfio.lib")

add_library(gltfio_core SHARED IMPORTED)
set_property(TARGET gltfio_core PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/gltfio_core.lib")
set_property(TARGET gltfio_core PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/gltfio_core.lib")
set_property(TARGET gltfio_core PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/gltfio_core.lib")

add_library(image SHARED IMPORTED)
set_property(TARGET image PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/image.lib")
set_property(TARGET image PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/image.lib")
set_property(TARGET image PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/image.lib")

add_library(imageio STATIC IMPORTED)
set_property(TARGET imageio PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/imageio.lib")
set_property(TARGET imageio  PROPERTY IMPORTED_LOCATION_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/imageio.lib")
set_property(TARGET imageio  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/imageio.lib")

add_library(tinyexr STATIC IMPORTED)
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/tinyexr.lib")
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/tinyexr.lib")
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/tinyexr.lib")

add_library(camutils SHARED IMPORTED)
set_property(TARGET camutils PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/camutils.lib")
set_property(TARGET camutils PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/camutils.lib")
set_property(TARGET camutils PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/camutils.lib")

add_library(filaflat SHARED IMPORTED)
set_property(TARGET filaflat PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/filaflat.lib")
set_property(TARGET filaflat PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filaflat.lib")
set_property(TARGET filaflat PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/filaflat.lib")

add_library(dracodec SHARED IMPORTED)
set_property(TARGET dracodec PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/dracodec.lib")
set_property(TARGET dracodec  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/dracodec.lib")
set_property(TARGET dracodec  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/dracodec.lib")

add_library(ibl SHARED IMPORTED)
set_property(TARGET ibl PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/ibl.lib")
set_property(TARGET ibl  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/ibl.lib")
set_property(TARGET ibl  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/ibl.lib")

add_library(ktxreader SHARED IMPORTED)
set_property(TARGET ktxreader PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/ktxreader.lib")
set_property(TARGET ktxreader PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/ktxreader.lib")
set_property(TARGET ktxreader PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/ktxreader.lib")

add_library(stb SHARED IMPORTED)
set_property(TARGET stb PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/stb.lib")
set_property(TARGET stb PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/stb.lib")
set_property(TARGET stb PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/stb.lib")

add_library(bluevk SHARED IMPORTED)
set_property(TARGET bluevk PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/bluevk.lib")
set_property(TARGET bluevk PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/bluevk.lib")
set_property(TARGET bluevk  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/bluevk.lib")

add_library(vkshaders SHARED IMPORTED)
set_property(TARGET vkshaders PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/vkshaders.lib")
set_property(TARGET vkshaders  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/vkshaders.lib")
set_property(TARGET vkshaders  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/vkshaders.lib")

add_library(uberzlib SHARED IMPORTED)
set_property(TARGET uberzlib PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/uberzlib.lib")
set_property(TARGET uberzlib  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/uberzlib.lib")
set_property(TARGET uberzlib  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/uberzlib.lib")

add_library(smol-v SHARED IMPORTED)
set_property(TARGET smol-v PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/smol-v.lib")
set_property(TARGET smol-v  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/smol-v.lib")
set_property(TARGET smol-v  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/smol-v.lib")

add_library(uberarchive SHARED IMPORTED)
set_property(TARGET uberarchive PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/uberarchive.lib")
set_property(TARGET uberarchive PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/uberarchive.lib")
set_property(TARGET uberarchive PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/uberarchive.lib")

add_library(meshoptimizer SHARED IMPORTED)
set_property(TARGET meshoptimizer PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/meshoptimizer.lib")
set_property(TARGET meshoptimizer PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/meshoptimizer.lib")
set_property(TARGET meshoptimizer  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/meshoptimizer.lib")

add_library(basis_transcoder SHARED IMPORTED)
set_property(TARGET basis_transcoder PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/basis_transcoder.lib")
set_property(TARGET basis_transcoder  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/basis_transcoder.lib")
set_property(TARGET basis_transcoder  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/basis_transcoder.lib")

add_library(z SHARED IMPORTED)
set_property(TARGET z PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/z.lib")
set_property(TARGET z PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/z.lib")
set_property(TARGET z PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/z.lib")

add_library(zstd SHARED IMPORTED)
set_property(TARGET zstd PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/zstd.lib")
set_property(TARGET zstd  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/zstd.lib")
set_property(TARGET zstd  PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/zstd.lib")

add_library(png SHARED IMPORTED)
set_property(TARGET png PROPERTY IMPORTED_IMPLIB_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/png.lib")
set_property(TARGET png PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/png.lib")
set_property(TARGET png PROPERTY IMPORTED_IMPLIB_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/png.lib")

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/../ios/include
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${PLUGIN_NAME} PRIVATE 
flutter
flutter_wrapper_plugin 
# bluegl
  gltfio
 gltfio_core 
 filament 
 backend 
 geometry 
#  filameshio 
 filamat 
 filabridge 
#  filament-iblprefilter 
 camutils 
 filaflat 
 dracodec 
 ibl 
 ktxreader 
 image
 imageio
 utils 
 stb 
 uberzlib 
 smol-v 
 uberarchive 
 meshoptimizer
 geometry
 basis_transcoder
 z
 zstd
 png
 tinyexr
 Shlwapi
 EGL
 GLESv2
#  d3d_compiler
#  opengl32
)

# List of absolute paths to libraries that should be bundled with the plugin
set(polyvox_filament_bundled_libraries
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/libEGL.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/libGLESv2.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/libc++.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/third_party_abseil-cpp_absl.dll
  ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/third_party_zlib.dll
  # ${CMAKE_CURRENT_SOURCE_DIR}/lib/Debug/d3dcompiler_47.dll
  PARENT_SCOPE
)

# get_cmake_property(_variableNames VARIABLES)
# list (SORT _variableNames)
# foreach (_variableName ${_variableNames})
#     message(STATUS "${_variableName}FOO=BAR${${_variableName}}")
# endforeach()