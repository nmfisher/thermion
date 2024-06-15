# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "thermion_flutter")
project(${PROJECT_NAME})

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -fPIC -Wno-unused-variable -Wno-unused-function")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -Wno-unused-variable -Wno-unused-function")

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "thermion_flutter_plugin")

link_directories("${CMAKE_CURRENT_SOURCE_DIR}/lib") 

add_library(FILAMENT_SHADERS SHARED 
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/image.c"
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/unlit_opaque.c" 
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
#
# Any new source files that you add to the plugin should be added here.
add_library(${PLUGIN_NAME} SHARED
 "thermion_flutter_plugin.cc"
 "filament_texture.cc"
 "filament_pb_texture.cc"
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/SceneManager.cpp"
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/ThermionViewerFFI.cpp"
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/ThermionFlutterApi.cpp"
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/StreamBufferAdapter.cpp"
 "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/TimeIt.cpp"
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

add_compile_definitions(IS_DLL)


# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
 "${CMAKE_CURRENT_SOURCE_DIR}/include")

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(../example/linux)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

add_library(geometry STATIC IMPORTED)
set_property(TARGET geometry PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libgeometry.a")
add_library(filament STATIC IMPORTED)
set_property(TARGET filament PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilament.a")
add_library(backend STATIC IMPORTED)
set_property(TARGET backend PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbackend.a")
add_library(filameshio STATIC IMPORTED)
set_property(TARGET filameshio PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilameshio.a")
add_library(filament_viewer STATIC IMPORTED)
set_property(TARGET filament_viewer PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libviewer.a")
add_library(filamat STATIC IMPORTED)
set_property(TARGET filamat PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilamat.a")
add_library(utils STATIC IMPORTED)
set_property(TARGET utils PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libutils.a")
add_library(filabridge STATIC IMPORTED)
set_property(TARGET filabridge PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilabridge.a")
add_library(gltfio_core STATIC IMPORTED)
set_property(TARGET gltfio_core PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libgltfio_core.a")
add_library(filament-iblprefilter STATIC IMPORTED)
set_property(TARGET filament-iblprefilter PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilament-iblprefilter.a")
add_library(image STATIC IMPORTED)
set_property(TARGET image PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libimage.a")
add_library(camutils STATIC IMPORTED)
set_property(TARGET camutils PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libcamutils.a")
add_library(filaflat STATIC IMPORTED)
set_property(TARGET filaflat PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libfilaflat.a")
add_library(dracodec STATIC IMPORTED)
set_property(TARGET dracodec PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libdracodec.a")
add_library(ibl STATIC IMPORTED)
set_property(TARGET ibl PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libibl.a")
add_library(ktxreader STATIC IMPORTED)
set_property(TARGET ktxreader PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libktxreader.a")
add_library(imageio STATIC IMPORTED)
set_property(TARGET imageio PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libimageio.a")
add_library(tinyexr STATIC IMPORTED)
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libtinyexr.a")
add_library(stb  STATIC IMPORTED)
set_property(TARGET stb  PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libstb.a")
add_library(bluevk STATIC IMPORTED)
set_property(TARGET bluevk PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbluevk.a")
add_library(vkshaders STATIC IMPORTED)
set_property(TARGET vkshaders PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libvkshaders.a")
add_library(bluegl STATIC IMPORTED)
set_property(TARGET bluegl PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbluegl.a")
add_library(uberzlib STATIC IMPORTED)
set_property(TARGET uberzlib PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libuberzlib.a")
add_library(smol-v STATIC IMPORTED)
set_property(TARGET smol-v PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libsmol-v.a")
add_library(uberarchive STATIC IMPORTED)
set_property(TARGET uberarchive PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libuberarchive.a")
add_library(meshoptimizer STATIC IMPORTED)
set_property(TARGET meshoptimizer PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libmeshoptimizer.a")
add_library(mathio STATIC IMPORTED)
set_property(TARGET mathio PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libmathio.a")
add_library(math STATIC IMPORTED)
set_property(TARGET math PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libmath.a")
add_library(basis_transcoder STATIC IMPORTED)
set_property(TARGET basis_transcoder PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/lib/libbasis_transcoder.a")

target_link_libraries(${PLUGIN_NAME} PRIVATE
 FILAMENT_SHADERS
 gltfio_core 
 filament 
 backend 
 geometry 
 filameshio 
 filament_viewer 
 filamat 
 filabridge 
 filament-iblprefilter 
 camutils 
 filaflat 
 dracodec 
 ibl 
 ktxreader 
 imageio
 image
 utils 
 tinyexr
 stb 
 bluevk 
 vkshaders 
 bluegl 
 uberzlib 
 smol-v 
 uberarchive 
 meshoptimizer
 mathio
 math
 geometry
 basis_transcoder
)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(thermion_flutter_bundled_libraries
 ""
 PARENT_SCOPE
 lib/libgeometry.a
)
