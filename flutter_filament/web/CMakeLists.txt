cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_filament")
project(${PROJECT_NAME})

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -fPIC -Wno-unused-variable -Wno-unused-function")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -Wno-unused-variable -Wno-unused-function")

set(PLUGIN_NAME "flutter_filament_plugin")

link_directories("${CMAKE_CURRENT_SOURCE_DIR}/lib") 

add_library(FILAMENT_SHADERS STATIC 
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/image.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/unlit_opaque.c"  
)

add_library(${PLUGIN_NAME} STATIC
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/SceneManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/FilamentViewer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/FlutterFilamentApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/StreamBufferAdapter.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/TimeIt.cpp"
)

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(../example/linux)

# add_library(geometry  STATIC IMPORTED)
# set_property(TARGET geometry  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libgeometry.a")
# add_library(filament  STATIC IMPORTED)
# set_property(TARGET filament  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilament.a")
# add_library(backend  STATIC IMPORTED)
# set_property(TARGET backend  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbackend.a")
# add_library(filameshio  STATIC IMPORTED)
# set_property(TARGET filameshio  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilameshio.a")
# add_library(filament_viewer  STATIC IMPORTED)
# set_property(TARGET filament_viewer  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libviewer.a")
# add_library(utils  STATIC IMPORTED)
# set_property(TARGET utils  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libutils.a")
# add_library(filabridge  STATIC IMPORTED)
# set_property(TARGET filabridge  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilabridge.a")
# add_library(gltfio_core  STATIC IMPORTED)
# set_property(TARGET gltfio_core  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libgltfio_core.a")
# add_library(filament-iblprefilter  STATIC IMPORTED)
# set_property(TARGET filament-iblprefilter  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilament-iblprefilter.a")
# add_library(image  STATIC IMPORTED)
# set_property(TARGET image  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libimage.a")
# add_library(camutils  STATIC IMPORTED)
# set_property(TARGET camutils  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libcamutils.a")
# add_library(filaflat  STATIC IMPORTED)
# set_property(TARGET filaflat  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilaflat.a")
# add_library(dracodec  STATIC IMPORTED)
# set_property(TARGET dracodec  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libdracodec.a")
# add_library(ibl  STATIC IMPORTED)
# set_property(TARGET ibl  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libibl.a")
# add_library(ktxreader  STATIC IMPORTED)
# set_property(TARGET ktxreader  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libktxreader.a")
# add_library(imageio STATIC IMPORTED)
# set_property(TARGET imageio PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libimageio.a")
# add_library(tinyexr STATIC IMPORTED)
# set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libtinyexr.a")
# add_library(stb   STATIC IMPORTED)
# set_property(TARGET stb   PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libstb.a")
# # add_library(bluegl  STATIC IMPORTED)
# # set_property(TARGET bluegl  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbluegl.a")
# add_library(uberzlib  STATIC IMPORTED)
# set_property(TARGET uberzlib  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libuberzlib.a")
# add_library(smol-v  STATIC IMPORTED)
# set_property(TARGET smol-v  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libsmol-v.a")
# add_library(png STATIC IMPORTED)
# set_property(TARGET png PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libpng.a")
# add_library(uberarchive  STATIC IMPORTED)
# set_property(TARGET uberarchive  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libuberarchive.a")
# add_library(meshoptimizer STATIC IMPORTED)
# set_property(TARGET meshoptimizer PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libmeshoptimizer.a")
# add_library(mathio STATIC IMPORTED)
# set_property(TARGET mathio PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libmathio.a")
# add_library(math STATIC IMPORTED)
# set_property(TARGET math PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libmath.a")
# add_library(basis_transcoder STATIC IMPORTED)
# set_property(TARGET basis_transcoder PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbasis_transcoder.a")
# add_library(z STATIC IMPORTED)
# set_property(TARGET z PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libz.a")

# target_link_libraries(${PLUGIN_NAME} PRIVATE
#   FILAMENT_SHADERS
#   gltfio_core 
#   filament 
#   backend 
#   geometry 
#   filameshio 
#   filament_viewer  
#   filabridge 
#   filament-iblprefilter 
#   camutils 
#   filaflat 
#   dracodec 
#   ibl 
#   ktxreader 
#   imageio
#   image
#   png
#   utils 
#   tinyexr
#   stb  
#   # bluegl 
#   uberzlib 
#   smol-v 
#   uberarchive 
#   meshoptimizer
#   mathio
#   math
#   geometry
#   basis_transcoder
#   z
# )

