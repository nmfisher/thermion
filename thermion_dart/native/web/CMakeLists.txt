cmake_minimum_required(VERSION 3.22)

set(PROJECT_NAME "thermion_dart")
project(${PROJECT_NAME})

option(THERMION_WEB_MAIN_THREAD
  "Run Thermion commands on the calling thread instead of a render worker" OFF)

# Runtime material compilation (filamat::MaterialBuilder). Opt-in: bakes
# glslang/SPIRV-Tools into the wasm (tens of MB), so the default engine
# leaves it out and wasm-ld dead-code-eliminates the unreferenced archive.
# The hook selects this build via the `runtime_materials` user define, and
# CI publishes it as the `-web-runtime-materials` artifact.
option(THERMION_ENABLE_RUNTIME_MATERIALS
  "Compile materials from GLSL source at runtime (links filamat)" OFF)

# Compile-time feature opt-outs (../include/ThermionFeatures.h).
# Every published web engine is built
# with all three ON (a zip per subset would multiply the variants); the
# options exist so a `-slim` engine can later be published as one extra
# suffix, exactly like `-runtime-materials`. Like the native hook, a switch is
# passed only when OFF, so default compile commands are unchanged. The link
# list below keeps naming every archive: wasm-ld only pulls referenced
# members, and the guards below remove the references.
option(THERMION_ENABLE_GLTF "Load glTF assets (gltfio_core, Draco, ubershader)" ON)
option(THERMION_ENABLE_KTX "KTX1/KTX2 textures (ktxreader, basis_transcoder)" ON)
option(THERMION_ENABLE_IMAGE_DECODING "PNG/JPEG decoding (stb)" ON)

# WebGPU needs the Emdawnwebgpu package from the Filament web archive.
# The browser's GPUDevice belongs to the thread that requested it.
option(THERMION_ENABLE_WEBGPU
  "Enable the WebGPU backend (requires a Filament web artifact built with FILAMENT_SUPPORTS_WEBGPU=ON)" OFF)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif(NOT CMAKE_BUILD_TYPE)

if(THERMION_ENABLE_WEBGPU)
  set(THERMION_WEB_MAIN_THREAD ON)
  set(FILAMENT_WEB_MODE release)
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(FILAMENT_WEB_MODE debug)
  endif()
  set(THERMION_DAWN_PORT
    "${CMAKE_CURRENT_SOURCE_DIR}/lib/${FILAMENT_WEB_MODE}/emdawnwebgpu_pkg/emdawnwebgpu.port.py")
  if(NOT EXISTS "${THERMION_DAWN_PORT}")
    message(FATAL_ERROR "Extract the Filament WebGPU archive into lib/${FILAMENT_WEB_MODE} first")
  endif()
endif()

set(MODULE_NAME "thermion_dart")

set(EMCC_CFLAGS --bind)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_TABLE_GROWTH=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_MEMORY_GROWTH=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORT_NAME=${MODULE_NAME})

set(EMCC_CFLAGS ${EMCC_CFLAGS} -sINITIAL_MEMORY=512mb)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMODULARIZE)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sERROR_ON_UNDEFINED_SYMBOLS=0 )
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORTED_RUNTIME_METHODS=wasmExports,wasmTable,addFunction,removeFunction,ccall,cwrap,intArrayFromString,intArrayToString,getValue,setValue,UTF8ToString,stringToUTF8,writeArrayToMemory,lengthBytesUTF8,HEAPU8,HEAPU32,HEAPF32)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORTED_FUNCTIONS=_malloc,stackAlloc,_free,stackSave,stackRestore)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFULL_ES3)
# Pre-spawn one worker per engine/viewer (matches WebOptions.maxViewers
# default). With a pool smaller than the viewer count, the Nth pthread_create
# takes emscripten's lazy-spawn path (spawn + wasm load mid-flight), which is
# fragile and can hang; the pool workers are loaded and awaited at module
# startup instead. Each worker receives its own canvas at thread start
# (emscripten_pthread_attr_settransferredcanvases).
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPTHREAD_POOL_SIZE=8)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_BLOCKING_ON_MAIN_THREAD=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMALLOC=mimalloc)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sOFFSCREENCANVAS_SUPPORT=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sOFFSCREEN_FRAMEBUFFER=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -fno-exceptions)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sASYNCIFY=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMIN_WEBGL_VERSION=2)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMAX_WEBGL_VERSION=2)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFETCH=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSHARED_MEMORY=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFILESYSTEM=0)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sASSERTIONS=2)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sGL_ASSERTIONS=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sGL_DEBUG=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSAFE_HEAP=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSAFE_HEAP_LOG=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSTACK_OVERFLOW_CHECK=2)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sWARN_UNALIGNED=1)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wcast-align -Wover-aligned")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wcast-align -Wover-aligned")
endif()

if(ENABLE_TRACING)
add_compile_definitions(ENABLE_TRACING=1)
message(STATUS "Enabling tracing")
endif()

# pthread stack size defaults to 10 MB.
# Override with -DTHERMION_STACK_SIZE=<bytes>.
if(NOT DEFINED THERMION_STACK_SIZE)
  set(THERMION_STACK_SIZE 10485760)
endif()
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSTACK_SIZE=${THERMION_STACK_SIZE})


# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPROXY_TO_PTHREAD=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} "-sOFFSCREENCANVASES_TO_PTHREAD=#thermion_canvas")
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPROXY_TO_WORKER=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sENVIRONMENT=web)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sENVIRONMENT=worker)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sLINKABLE=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSIDE_MODULE)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++ -std=c++17 -Wno-invalid-specialization -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=1")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O1") #-fsanitize=undefined
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -O1")
endif()

# Set to "ON" to enable verbose linking
set(CMAKE_VERBOSE_MAKEFILE OFF)

add_link_options(${EMCC_CFLAGS} -pthread)
set(MATERIAL_READER "${CMAKE_CURRENT_SOURCE_DIR}/src/read_material.js")
add_link_options(--post-js "${MATERIAL_READER}")

link_directories("${CMAKE_CURRENT_SOURCE_DIR}/lib")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY build/out)

# The Dart build hook and download_web embed selected materials as custom
# sections in a copy of this engine.
file(GLOB SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/c_api/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/c_api/transform_pipeline/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/components/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/rendering/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/scene/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/transform_pipeline/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../include/resources/*.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/ThermionWebApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/WebJobThread.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/RenderManagerWeb.cpp"
   # "${CMAKE_CURRENT_SOURCE_DIR}/../src/rendering/EmscriptenTest.cpp"
  )

# The Dart native build hook compiles NativeJobThread from native/src.
# Web supplies its own implementation, outside that source tree.
list(REMOVE_ITEM SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../src/rendering/NativeJobThread.cpp")

if(DEFINED EXTERNAL_PROJECTS)

  foreach(external_project ${EXTERNAL_PROJECTS})
    message(STATUS "Processing external project: ${external_project}")

    if(EXISTS "${external_project}")
      message(STATUS "Found external project at: ${external_project}")

      include("${external_project}")

      message(STATUS "Successfully included external project: ${external_project}")
    else()
      message(WARNING "External project file not found: ${external_project}")
    endif()
  endforeach()

  if(EXTERNAL_ALL_LIBRARIES)
    message(STATUS "Total external project libraries: ${EXTERNAL_ALL_LIBRARIES}")
  else()
    message(STATUS "No external project libraries found")
  endif()

  message(STATUS "Completed processing external projects")
else()
  message(STATUS "EXTERNAL_PROJECTS variable is NOT defined - no external projects will be included")
endif()

message(STATUS "Total source files being compiled: ${SOURCES}")
add_executable(${MODULE_NAME} ${SOURCES})
set_property(TARGET ${MODULE_NAME} APPEND PROPERTY LINK_DEPENDS "${MATERIAL_READER}")
if(THERMION_WEB_MAIN_THREAD)
  target_compile_definitions(${MODULE_NAME} PRIVATE THERMION_WEB_MAIN_THREAD=1)
endif()
if(THERMION_ENABLE_WEBGPU)
  set(WEBGPU_DEVICE_JS "${CMAKE_CURRENT_SOURCE_DIR}/src/webgpu_device.js")
  # Match Filament's RTTI settings in the platform adapter. The Web API's
  # separate Emscripten bindings still use RTTI.
  set(WEBGPU_PLATFORM "${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/ThermionWebGPUPlatform.cpp")
  target_sources(${MODULE_NAME} PRIVATE "${WEBGPU_PLATFORM}")
  set_source_files_properties("${WEBGPU_PLATFORM}" PROPERTIES COMPILE_OPTIONS "-fno-rtti")
  target_compile_options(${MODULE_NAME} PRIVATE "--use-port=${THERMION_DAWN_PORT}")
  target_compile_features(${MODULE_NAME} PRIVATE cxx_std_20)
  target_link_options(${MODULE_NAME} PRIVATE "--use-port=${THERMION_DAWN_PORT}"
    --pre-js "${WEBGPU_DEVICE_JS}")
  set_property(TARGET ${MODULE_NAME} APPEND PROPERTY LINK_DEPENDS "${WEBGPU_DEVICE_JS}")
  target_compile_definitions(${MODULE_NAME} PRIVATE THERMION_SUPPORTS_WEBGPU=1)
  message(STATUS "WebGPU backend enabled (THERMION_ENABLE_WEBGPU=ON)")
endif()

set_target_properties(${MODULE_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${MODULE_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_compile_options(${MODULE_NAME} PRIVATE -matomics -mbulk-memory)
target_compile_options(${MODULE_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>")
target_compile_features(${MODULE_NAME} PRIVATE cxx_std_17)


include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../src)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/../include)
# Filament headers come from the version-matched web R2 artifact, extracted by
# the `make wasm` target into lib/<mode>/include/ (flat layout, with the
# web-specific gltfio/materials/uberarchive.h). This replaces a committed
# Filament header tree that could drift on version bumps.
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(FILAMENT_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/include")
else()
  set(FILAMENT_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/include")
endif()
include_directories(${FILAMENT_HEADERS_DIR})


add_library(backend STATIC IMPORTED)
set_property(TARGET backend PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libbackend.a")
set_property(TARGET backend PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbackend.a")
set_property(TARGET backend PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libbackend.a")

add_library(geometry STATIC IMPORTED)
set_property(TARGET geometry PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libgeometry.a")
set_property(TARGET geometry PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libgeometry.a")
set_property(TARGET geometry PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libgeometry.a")

add_library(mikktspace STATIC IMPORTED)
set_property(TARGET mikktspace PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libmikktspace.a")
set_property(TARGET mikktspace PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libmikktspace.a")
set_property(TARGET mikktspace PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libmikktspace.a")

add_library(filament STATIC IMPORTED)
set_property(TARGET filament PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilament.a")
set_property(TARGET filament PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilament.a")
set_property(TARGET filament PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilament.a")

add_library(filamat STATIC IMPORTED)
# NB: the web artifact flattens filament's BUILD tree, where the filamat-only
# archive is libfilamat.a and the full archive (filamat + glslang +
# SPIRV-Tools + spirv-cross + zstd) keeps its libfilamat_combined.a name —
# native platform zips rename the combined archive TO libfilamat.a instead.
# Link the combined one or glslang/SPIRV symbols won't resolve.
set_property(TARGET filamat PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilamat_combined.a")
set_property(TARGET filamat  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilamat_combined.a")
set_property(TARGET filamat  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilamat_combined.a")

# smol-v ships complete in every filament zip (web release confirmed; native
# zips install it via the same install rule). It must be linked DIRECTLY, not
# via libfilamat_combined.a: the combined archive is assembled by filament's
# combine-static-libs.sh with `ar -qc` (quick append), which does not
# regenerate the archive's symbol table — members appended that way are
# invisible to linker symbol lookup, so the smolv::Encode etc. members our
# smolv patch added would still be unresolvable. See the smol_v link in the
# runtime-materials section below.
add_library(smol_v STATIC IMPORTED)
set_property(TARGET smol_v PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libsmol-v.a")
set_property(TARGET smol_v  PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libsmol-v.a")
set_property(TARGET smol_v  PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libsmol-v.a")

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
set_property(TARGET png PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libpng16d.a")
set_property(TARGET png PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libpng16.a")
set_property(TARGET png PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libpng16.a")

# Diagnostic: Check if EXTERNAL_ALL_LIBRARIES is visible
if(DEFINED EXTERNAL_ALL_LIBRARIES)
  message(STATUS "EXTERNAL_ALL_LIBRARIES is defined at link time: ${EXTERNAL_ALL_LIBRARIES}")

  # Check if the targets actually exist
  foreach(lib ${EXTERNAL_ALL_LIBRARIES})
    if(TARGET ${lib})
      message(STATUS "  Target ${lib} exists")
    else()
      message(WARNING "  Target ${lib} does NOT exist!")
    endif()
  endforeach()
else()
  message(STATUS "EXTERNAL_ALL_LIBRARIES is NOT defined at link time")
endif()

target_link_libraries(${MODULE_NAME}
 gltfio_core
 filament
 backend
 geometry
 mikktspace
 dracodec
 ibl-lite
 ktxreader
 filaflat
 filabridge
 image
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
 ${EXTERNAL_ALL_LIBRARIES}
)

# Runtime material compilation. filamat's combined archive already bundles
# glslang/SPIRV/spirv-cross/zstd; shaders provides the SHADERS_PACKAGE chunks
# CodeGenerator bakes into every material. matp (the .mat parser behind matc,
# for compileMaterialPackage) references filamat, so it comes BEFORE it;
# smol_v comes AFTER filamat (it is a leaf library filamat references).
if(THERMION_ENABLE_RUNTIME_MATERIALS)
  add_library(shaders STATIC IMPORTED)
  set_property(TARGET shaders PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libshaders.a")
  set_property(TARGET shaders PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libshaders.a")
  set_property(TARGET shaders PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libshaders.a")
  add_library(matp STATIC IMPORTED)
  set_property(TARGET matp PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libmatp.a")
  set_property(TARGET matp PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libmatp.a")
  set_property(TARGET matp PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libmatp.a")
  target_link_libraries(${MODULE_NAME} matp filamat shaders smol_v)
  message(STATUS "Runtime material compilation enabled (matp + filamat + smol-v linked)")
endif()

# The macro is a value check: always pass 0 or 1 so a build with the option
# off cannot fall back to presence semantics.
target_compile_definitions(${MODULE_NAME}
  PRIVATE THERMION_ENABLE_RUNTIME_MATERIALS=$<BOOL:${THERMION_ENABLE_RUNTIME_MATERIALS}>)

# Feature opt-outs: only DISABLED features are passed (=0); the header defaults
# every switch to 1, so the all-on build defines nothing (see
# ../include/ThermionFeatures.h). Thermion_getEnabledFeatures reports the
# resulting bitmask to Dart.
foreach(_feature GLTF KTX IMAGE_DECODING)
  if(NOT THERMION_ENABLE_${_feature})
    target_compile_definitions(${MODULE_NAME} PRIVATE THERMION_ENABLE_${_feature}=0)
    message(STATUS "Feature disabled: THERMION_ENABLE_${_feature}=0")
  endif()
endforeach()

# Force linker to include all symbols from external libraries (prevents dead code elimination)
# This is critical because nothing in Thermion directly references these libraries
if(DEFINED EXTERNAL_ALL_LIBRARIES)
  foreach(lib ${EXTERNAL_ALL_LIBRARIES})
    target_link_options(${MODULE_NAME} PRIVATE
      "SHELL:-Wl,--whole-archive $<TARGET_FILE:${lib}> -Wl,--no-whole-archive"
    )
  endforeach()
  message(STATUS "Added --whole-archive flags for external libraries to prevent dead code elimination")
endif()
