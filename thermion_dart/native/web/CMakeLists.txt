cmake_minimum_required(VERSION 3.22)

set(PROJECT_NAME "thermion_dart")
project(${PROJECT_NAME})

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif(NOT CMAKE_BUILD_TYPE)

set(MODULE_NAME "thermion_dart")

set(EMCC_CFLAGS --bind)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_TABLE_GROWTH=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_MEMORY_GROWTH=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORT_NAME=${MODULE_NAME})

set(EMCC_CFLAGS ${EMCC_CFLAGS} -sINITIAL_MEMORY=512mb)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMODULARIZE)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sERROR_ON_UNDEFINED_SYMBOLS=0 )
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORTED_RUNTIME_METHODS=wasmExports,wasmTable,addFunction,removeFunction,ccall,cwrap,allocate,intArrayFromString,intArrayToString,getValue,setValue,UTF8ToString,stringToUTF8,writeArrayToMemory,lengthBytesUTF8,HEAPU8,HEAPF32)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sEXPORTED_FUNCTIONS=_malloc,stackAlloc,_free,stackSave,stackRestore)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFULL_ES3)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPTHREAD_POOL_SIZE=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sALLOW_BLOCKING_ON_MAIN_THREAD=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMALLOC=mimalloc)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sOFFSCREENCANVAS_SUPPORT=1)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sNO_DISABLE_EXCEPTION_CATCHING)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sASYNCIFY=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMIN_WEBGL_VERSION=2)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sMAX_WEBGL_VERSION=2)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFETCH=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSHARED_MEMORY=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sFILESYSTEM=0)
set(EMCC_CFLAGS ${EMCC_CFLAGS} -sUSE_PTHREADS)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sASSERTIONS=2)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sGL_ASSERTIONS=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sGL_DEBUG=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSAFE_HEAP=1)
  # add_compile_definitions(ENABLE_TRACING=1)
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sWARN_UNALIGNED=1)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wcast-align -Wover-aligned")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wcast-align -Wover-aligned")
  set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSTACK_SIZE=10485760)
endif()

set(EMCC_CFLAGS ${EMCC_CFLAGS} -sSTACK_SIZE=10485760)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPROXY_TO_PTHREAD=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} "-sOFFSCREENCANVASES_TO_PTHREAD=#thermion_canvas")
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sPROXY_TO_WORKER=1)
# set(EMCC_CFLAGS ${EMCC_CFLAGS} -sOFFSCREEN_FRAMEBUFFER=1)
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

add_link_options(${EMCC_CFLAGS} -pthread)

link_directories("${CMAKE_CURRENT_SOURCE_DIR}/lib") 

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY build/out)

file(GLOB SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/**/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../include/resources/*.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../include/material/*.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/cpp/ThermionWebApi.cpp"
   # "${CMAKE_CURRENT_SOURCE_DIR}/../src/rendering/EmscriptenTest.cpp"
  )

# Add plugin sources if provided
if(DEFINED PLUGIN_SOURCES)
  message(STATUS "PLUGIN_SOURCES variable is defined!")
  message(STATUS "Raw PLUGIN_SOURCES value: ${PLUGIN_SOURCES}")
  # Plugin sources are now absolute paths, add them directly
  foreach(plugin_source ${PLUGIN_SOURCES})
    message(STATUS "Adding plugin source: ${plugin_source}")
    list(APPEND SOURCES "${plugin_source}")
  endforeach()
  message(STATUS "Final SOURCES list now has plugin sources included")
else()
  message(STATUS "PLUGIN_SOURCES variable is NOT defined - no standalone plugins will be included")
endif()

# Process plugin configurations if provided
if(DEFINED PLUGIN_CONFIGURATIONS AND DEFINED PLUGIN_BASE_DIR)
  message(STATUS "PLUGIN_CONFIGURATIONS variable is defined!")
  message(STATUS "Raw PLUGIN_CONFIGURATIONS value: ${PLUGIN_CONFIGURATIONS}")
  message(STATUS "Plugin base directory: ${PLUGIN_BASE_DIR}")

  # Create a variable to collect all plugin sources
  set(PLUGIN_ALL_SOURCES "")
  set(PLUGIN_ALL_INCLUDE_DIRS "")
  set(PLUGIN_ALL_LIBRARIES "")
  set(PLUGIN_ALL_LIBRARY_DIRS "")
  set(PLUGIN_ALL_DEFINES "")

  # Process each plugin configuration
  foreach(plugin_config ${PLUGIN_CONFIGURATIONS})
    message(STATUS "Processing plugin configuration: ${plugin_config}")

    # Create the full path to the configuration file
    set(plugin_config_path "${PLUGIN_BASE_DIR}/${plugin_config}")

    # Check if the configuration file exists
    if(EXISTS "${plugin_config_path}")
      message(STATUS "Found plugin configuration at: ${plugin_config_path}")

      # Include the plugin configuration file
      include("${plugin_config_path}")

      # Process plugin source files (relative to plugin configuration directory)
      if(DEFINED PLUGIN_SOURCES)
        set(plugin_dir "${PLUGIN_BASE_DIR}")
        foreach(plugin_source ${PLUGIN_SOURCES})
          set(plugin_source_abs "${plugin_dir}/${plugin_source}")
          if(EXISTS "${plugin_source_abs}")
            list(APPEND PLUGIN_ALL_SOURCES "${plugin_source_abs}")
            message(STATUS "Adding plugin source: ${plugin_source_abs}")
          else()
            message(WARNING "Plugin source file not found: ${plugin_source_abs}")
          endif()
        endforeach()
      endif()

      # Process plugin include directories (relative to plugin configuration directory)
      if(DEFINED PLUGIN_INCLUDE_DIRS)
        set(plugin_dir "${PLUGIN_BASE_DIR}")
        foreach(plugin_include ${PLUGIN_INCLUDE_DIRS})
          set(plugin_include_abs "${plugin_dir}/${plugin_include}")
          if(EXISTS "${plugin_include_abs}")
            list(APPEND PLUGIN_ALL_INCLUDE_DIRS "${plugin_include_abs}")
            message(STATUS "Adding plugin include directory: ${plugin_include_abs}")
          else()
            message(WARNING "Plugin include directory not found: ${plugin_include_abs}")
          endif()
        endforeach()
      endif()

      # Process plugin library directories (relative to plugin configuration directory)
      if(DEFINED PLUGIN_LIBRARY_DIRS)
        set(plugin_dir "${PLUGIN_BASE_DIR}")
        foreach(plugin_lib_dir ${PLUGIN_LIBRARY_DIRS})
          set(plugin_lib_dir_abs "${plugin_dir}/${plugin_lib_dir}")
          if(EXISTS "${plugin_lib_dir_abs}")
            list(APPEND PLUGIN_ALL_LIBRARY_DIRS "${plugin_lib_dir_abs}")
            message(STATUS "Adding plugin library directory: ${plugin_lib_dir_abs}")
          else()
            message(WARNING "Plugin library directory not found: ${plugin_lib_dir_abs}")
          endif()
        endforeach()
      endif()

      # Collect plugin libraries and defines
      if(DEFINED PLUGIN_LIBRARIES)
        list(APPEND PLUGIN_ALL_LIBRARIES ${PLUGIN_LIBRARIES})
        message(STATUS "Adding plugin libraries: ${PLUGIN_LIBRARIES}")
      endif()

      if(DEFINED PLUGIN_DEFINES)
        list(APPEND PLUGIN_ALL_DEFINES ${PLUGIN_DEFINES})
        message(STATUS "Adding plugin defines: ${PLUGIN_DEFINES}")
      endif()

      # Handle plugin compile options (e.g., C++ standard requirements)
      if(DEFINED PLUGIN_COMPILE_OPTIONS)
        list(APPEND PLUGIN_ALL_COMPILE_OPTIONS ${PLUGIN_COMPILE_OPTIONS})
        message(STATUS "Adding plugin compile options: ${PLUGIN_COMPILE_OPTIONS}")
      endif()

      # Clear plugin-specific variables for next iteration
      unset(PLUGIN_SOURCES)
      unset(PLUGIN_INCLUDE_DIRS)
      unset(PLUGIN_LIBRARIES)
      unset(PLUGIN_LIBRARY_DIRS)
      unset(PLUGIN_DEFINES)
      unset(PLUGIN_COMPILE_OPTIONS)

    else()
      message(WARNING "Plugin configuration file not found: ${plugin_config_path}")
    endif()
  endforeach()

  # Add all collected plugin sources to main sources
  if(PLUGIN_ALL_SOURCES)
    list(APPEND SOURCES ${PLUGIN_ALL_SOURCES})
    message(STATUS "Added ${CMAKE_MATCH_COUNT} plugin sources from configurations")
  endif()

  # Add plugin include directories
  if(PLUGIN_ALL_INCLUDE_DIRS)
    foreach(include_dir ${PLUGIN_ALL_INCLUDE_DIRS})
      include_directories(${include_dir})
    endforeach()
    message(STATUS "Added plugin include directories")
  endif()

  # Add plugin library directories to link directories
  if(PLUGIN_ALL_LIBRARY_DIRS)
    foreach(lib_dir ${PLUGIN_ALL_LIBRARY_DIRS})
      link_directories(${lib_dir})
    endforeach()
    message(STATUS "Added plugin library directories")
  endif()

  # Add plugin defines
  if(PLUGIN_ALL_DEFINES)
    foreach(define ${PLUGIN_ALL_DEFINES})
      add_compile_definitions(${define})
    endforeach()
    message(STATUS "Added plugin compile definitions: ${PLUGIN_ALL_DEFINES}")
  endif()

  # Store plugin libraries for later linking
  set(PLUGIN_LIBRARIES ${PLUGIN_ALL_LIBRARIES} CACHE STRING "Plugin libraries")

else()
  message(STATUS "PLUGIN_CONFIGURATIONS variable is NOT defined - no configured plugins will be included")
endif()

message(STATUS "Total source files being compiled: ${SOURCES}")
add_executable(${MODULE_NAME} ${SOURCES})

set_target_properties(${MODULE_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${MODULE_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_compile_options(${MODULE_NAME} PRIVATE -matomics -mbulk-memory)
target_compile_features(${MODULE_NAME} PRIVATE cxx_std_17)

# Apply plugin-specific compile options
if(PLUGIN_ALL_COMPILE_OPTIONS)
  # Apply compile options only to C++ files to avoid conflicts with C files
  foreach(option ${PLUGIN_ALL_COMPILE_OPTIONS})
    target_compile_options(${MODULE_NAME} PRIVATE $<$<COMPILE_LANGUAGE:CXX>:${option}>)
  endforeach()
  message(STATUS "Applied plugin compile options to C++ files: ${PLUGIN_ALL_COMPILE_OPTIONS}")
endif()

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
set_property(TARGET filament PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilament.a")

add_library(filameshio STATIC IMPORTED)
set_property(TARGET filameshio PROPERTY IMPORTED_LOCATION_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/lib/debug/libfilameshio.a")
set_property(TARGET filameshio PROPERTY IMPORTED_IMPLIB_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilameshio.a")
set_property(TARGET filameshio PROPERTY IMPORTED_LOCATION_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/lib/release/libfilameshio.a")

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

# Link plugin libraries if any
if(DEFINED PLUGIN_LIBRARIES)
  message(STATUS "Linking plugin libraries: ${PLUGIN_LIBRARIES}")
  target_link_libraries(${MODULE_NAME} ${PLUGIN_LIBRARIES})
endif()

