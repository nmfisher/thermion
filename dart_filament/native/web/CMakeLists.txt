cmake_minimum_required(VERSION 3.27)

set(PROJECT_NAME "dart_filament")
project(${PROJECT_NAME})

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif(NOT CMAKE_BUILD_TYPE)

set(MODULE_NAME "dart_filament")

set(EMCC_CFLAGS --bind)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_TABLE_GROWTH=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_MEMORY_GROWTH=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORT_NAME=${MODULE_NAME})
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORT_ALL=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sLINKABLE=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMAIN_MODULE)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORTED_FUNCTIONS=_create_filament_viewer_ffi)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMODULARIZE)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sERROR_ON_UNDEFINED_SYMBOLS=0 )
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORTED_RUNTIME_METHODS=wasmExports,wasmTable)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFULL_ES3)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sASSERTIONS)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPTHREAD_POOL_SIZE=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_BLOCKING_ON_MAIN_THREAD=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sOFFSCREEN_FRAMEBUFFER)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sNO_DISABLE_EXCEPTION_CATCHING)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sASYNCIFY=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sUSE_WEBGL2=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFETCH=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMIN_WEBGL_VERSION=2)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-missing-field-initializers -Wno-deprecated-literal-operator -stdlib=libc++ -std=c++17 -fPIC -pthread -O3")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")

add_link_options(${EMCC_CFLAGS})

link_directories("${CMAKE_CURRENT_SOURCE_DIR}/lib") 

add_library(filament_shaders STATIC 
  "${CMAKE_CURRENT_SOURCE_DIR}/../web/include/material/image.c"
)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY build/out)

add_executable(${MODULE_NAME} 
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/SceneManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/FilamentViewer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/DartFilamentApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/DartFilamentFFIApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/StreamBufferAdapter.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/TimeIt.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/camutils/Manipulator.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/camutils/Bookmark.cpp"
  # "${CMAKE_CURRENT_SOURCE_DIR}/../include/material/image.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../include/material/gizmo.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/DartFilamentWebApi.cpp"
)
set_target_properties(${MODULE_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${MODULE_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_compile_features(${MODULE_NAME} PRIVATE cxx_std_17)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../src)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../include/filament)

add_library(backend STATIC IMPORTED)
set_property(TARGET backend PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libbackend.a")
set_property(TARGET backend PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbackend.a")
set_property(TARGET backend PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbackend.a")

add_library(geometry STATIC IMPORTED)
set_property(TARGET geometry PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libgeometry.a")
set_property(TARGET geometry PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libgeometry.a")
set_property(TARGET geometry PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libgeometry.a")

add_library(filament STATIC IMPORTED)
set_property(TARGET filament PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilament.a")
set_property(TARGET filament PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilament.a")
set_property(TARGET filament PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libfilament.a")

add_library(filameshio STATIC IMPORTED)
set_property(TARGET filameshio PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilameshio.a")
set_property(TARGET filameshio PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libfilameshio.a")
set_property(TARGET filameshio PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/Release/libfilameshio.a")

add_library(filamat STATIC IMPORTED)
set_property(TARGET filamat PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilamat.a")
set_property(TARGET filamat  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilamat.a")
set_property(TARGET filamat  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilamat.a")

add_library(utils STATIC IMPORTED)
set_property(TARGET utils PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libutils.a")
set_property(TARGET utils PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libutils.a")
set_property(TARGET utils PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libutils.a")

add_library(filabridge STATIC IMPORTED)
set_property(TARGET filabridge PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilabridge.a")
set_property(TARGET filabridge PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilabridge.a")
set_property(TARGET filabridge PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilabridge.a")


add_library(gltfio_core STATIC IMPORTED)
set_property(TARGET gltfio_core PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libgltfio_core.a")
set_property(TARGET gltfio_core PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libgltfio_core.a")

add_library(image STATIC IMPORTED)
set_property(TARGET image PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libimage.a")
set_property(TARGET image PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libimage.a")
set_property(TARGET image PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libimage.a")

add_library(imageio STATIC IMPORTED)
set_property(TARGET imageio PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libimageio.a")
set_property(TARGET imageio  PROPERTY IMPORTED_LOCATION_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libimageio.a")
set_property(TARGET imageio  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libimageio.a")

add_library(tinyexr STATIC IMPORTED)
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libtinyexr.a")
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libtinyexr.a")
set_property(TARGET tinyexr PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libtinyexr.a")

add_library(camutils STATIC IMPORTED)
set_property(TARGET camutils PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libcamutils.a")
set_property(TARGET camutils PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libcamutils.a")
set_property(TARGET camutils PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libcamutils.a")

add_library(filaflat STATIC IMPORTED)
set_property(TARGET filaflat PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilaflat.a")
set_property(TARGET filaflat PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilaflat.a")
set_property(TARGET filaflat PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilaflat.a")

add_library(dracodec STATIC IMPORTED)
set_property(TARGET dracodec PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libdracodec.a")
set_property(TARGET dracodec  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libdracodec.a")
set_property(TARGET dracodec  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libdracodec.a")

add_library(ibl-lite STATIC IMPORTED)
set_property(TARGET ibl-lite PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libibl-lite.a")
set_property(TARGET ibl-lite  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libibl-lite.a")
set_property(TARGET ibl-lite  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libibl-lite.a")

add_library(ktxreader STATIC IMPORTED)
set_property(TARGET ktxreader PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libktxreader.a")
set_property(TARGET ktxreader PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libktxreader.a")
set_property(TARGET ktxreader PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libktxreader.a")

add_library(stb STATIC IMPORTED)
set_property(TARGET stb PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libstb.a")
set_property(TARGET stb PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libstb.a")
set_property(TARGET stb PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libstb.a")

add_library(uberzlib STATIC IMPORTED)
set_property(TARGET uberzlib PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libuberzlib.a")
set_property(TARGET uberzlib  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libuberzlib.a")
set_property(TARGET uberzlib  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libuberzlib.a")

add_library(uberarchive STATIC IMPORTED)
set_property(TARGET uberarchive PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libuberarchive.a")
set_property(TARGET uberarchive PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libuberarchive.a")
set_property(TARGET uberarchive PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libuberarchive.a")

add_library(meshoptimizer STATIC IMPORTED)
set_property(TARGET meshoptimizer PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libmeshoptimizer.a")
set_property(TARGET meshoptimizer PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libmeshoptimizer.a")
set_property(TARGET meshoptimizer  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libmeshoptimizer.a")

add_library(basis_transcoder STATIC IMPORTED)
set_property(TARGET basis_transcoder PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libbasis_transcoder.a")
set_property(TARGET basis_transcoder  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbasis_transcoder.a")
set_property(TARGET basis_transcoder  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbasis_transcoder.a")

add_library(basis_encoder STATIC IMPORTED)
set_property(TARGET basis_encoder PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libbasis_encoder.a")
set_property(TARGET basis_encoder  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbasis_encoder.a")
set_property(TARGET basis_encoder  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbasis_encoder.a")

add_library(z STATIC IMPORTED)
set_property(TARGET z PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libz.a")
set_property(TARGET z PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libz.a")
set_property(TARGET z PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libz.a")

add_library(zstd STATIC IMPORTED)
set_property(TARGET zstd PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libzstd.a")
set_property(TARGET zstd  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libzstd.a")
set_property(TARGET zstd  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libzstd.a")

add_library(png STATIC IMPORTED)
set_property(TARGET png PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libpng.a")
set_property(TARGET png PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libpng.a")
set_property(TARGET png PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libpng.a")

target_link_libraries(${MODULE_NAME}  
 filament_shaders
 gltfio_core 
 filament 
 backend 
 geometry 
 dracodec 
 ibl-lite
 ktxreader 
 filaflat
 filabridge
 image
 imageio
 utils 
 stb 
 uberzlib 
 uberarchive 
 meshoptimizer
 basis_transcoder
 basis_encoder
 z
 zstd
 png
 tinyexr
)








