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
  # "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/uberarchive.c" 
)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_20)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_library(bluegl SHARED IMPORTED)
set_property(TARGET bluegl PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/bluegl.lib")
add_library(geometry SHARED IMPORTED)
set_property(TARGET geometry PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/geometry.lib")
add_library(filament SHARED IMPORTED)
set_property(TARGET filament PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/filament.lib")
add_library(backend SHARED IMPORTED)
set_property(TARGET backend PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/backend.lib")
add_library(filameshio SHARED IMPORTED)
set_property(TARGET filameshio PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/filameshio.lib")
add_library(filament_viewer SHARED IMPORTED)
set_property(TARGET filament_viewer PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/viewer.lib")
add_library(filamat SHARED IMPORTED)
set_property(TARGET filamat PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/filamat.lib")
add_library(utils SHARED IMPORTED)
set_property(TARGET utils PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/utils.lib")
add_library(filabridge SHARED IMPORTED)
set_property(TARGET filabridge PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/filabridge.lib")
add_library(gltfio SHARED IMPORTED)
set_property(TARGET gltfio PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/gltfio.lib")
add_library(gltfio_core SHARED IMPORTED)
set_property(TARGET gltfio_core PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/gltfio_core.lib")
add_library(filament-iblprefilter SHARED IMPORTED)
set_property(TARGET filament-iblprefilter PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/filament-iblprefilter.lib")
add_library(image SHARED IMPORTED)
set_property(TARGET image PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/image.lib")
add_library(imageio STATIC IMPORTED)
set_property(TARGET imageio PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/imageio.lib")
add_library(tinyexr STATIC IMPORTED)
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/tinyexr.lib")
add_library(camutils SHARED IMPORTED)
set_property(TARGET camutils PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/camutils.lib")
add_library(filaflat SHARED IMPORTED)
set_property(TARGET filaflat PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/filaflat.lib")
add_library(dracodec SHARED IMPORTED)
set_property(TARGET dracodec PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/dracodec.lib")
add_library(ibl SHARED IMPORTED)
set_property(TARGET ibl PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/ibl.lib")
add_library(ktxreader SHARED IMPORTED)
set_property(TARGET ktxreader PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/ktxreader.lib")
add_library(stb  SHARED IMPORTED)
set_property(TARGET stb  PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/stb.lib")
add_library(bluevk SHARED IMPORTED)
set_property(TARGET bluevk PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/bluevk.lib")
add_library(vkshaders SHARED IMPORTED)
set_property(TARGET vkshaders PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/vkshaders.lib")
add_library(uberzlib SHARED IMPORTED)
set_property(TARGET uberzlib PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/uberzlib.lib")
add_library(smol-v SHARED IMPORTED)
set_property(TARGET smol-v PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/smol-v.lib")
# add_library(uberarchive SHARED IMPORTED)
# set_property(TARGET uberarchive PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/uberarchive.lib")
add_library(meshoptimizer SHARED IMPORTED)
set_property(TARGET meshoptimizer PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/meshoptimizer.lib")
add_library(basis_transcoder SHARED IMPORTED)
set_property(TARGET basis_transcoder PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/basis_transcoder.lib")
add_library(z SHARED IMPORTED)
set_property(TARGET z PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/z.lib")
add_library(zstd SHARED IMPORTED)
set_property(TARGET zstd PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/zstd.lib")
add_library(png SHARED IMPORTED)
set_property(TARGET png PROPERTY IMPORTED_IMPLIB "${CMAKE_CURRENT_SOURCE_DIR}/lib/png.lib")

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../ios/include)

get_cmake_property(_variableNames VARIABLES)
list (SORT _variableNames)
foreach (_variableName ${_variableNames})
    message(STATUS "${_variableName}FOO=BAR${${_variableName}}")
endforeach()

target_link_libraries(${PLUGIN_NAME} PRIVATE 
flutter
flutter_wrapper_plugin 
bluegl
opengl32
  gltfio
 gltfio_core 
 filament 
 backend 
 geometry 
#  filameshio 
 filamat 
 filabridge 
 filament-iblprefilter 
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
#  uberarchive 
 meshoptimizer
 geometry
 basis_transcoder
 z
 zstd
 png
 tinyexr
 Shlwapi
)

# List of absolute paths to libraries that should be bundled with the plugin
set(polyvox_filament_bundled_libraries
  ""
  PARENT_SCOPE
  windows/lib/*.lib
)
