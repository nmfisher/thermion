cmake_minimum_required(VERSION 3.10)  

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(../ios/include/stb)
include_directories(src/main/cpp)
link_directories(src/main/jniLibs/${ANDROID_ABI}) 
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")

add_library(polyvox_filament_android SHARED
"${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/PolyvoxFilamentApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/FilamentAndroid.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/AssetManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/FilamentViewer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/StreamBufferAdapter.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/TimeIt.cpp"
)

add_library(FILAMENT_SHADERS SHARED 
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/image.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/unlit_opaque.c"  
)

include_directories(../ios/include)

target_link_libraries(
  polyvox_filament_android
  FILAMENT_SHADERS
  -landroid
  -llog
  -lgltfio_core 
  -lfilament 
  -lbackend 
  -lgeometry 
  -lfilameshio 
  -lfilamat 
  -lfilabridge 
  -lfilament-iblprefilter 
  -lcamutils 
  -lfilaflat 
  -ldracodec 
  -libl 
  -lktxreader 
  -limageio
  -limage
  -lutils 
  -ltinyexr
  -lstb  
  -lbluevk 
  -lvkshaders 
  -luberzlib 
  -lsmol-v 
  -luberarchive 
  -lmeshoptimizer
  -lgeometry
  -lbasis_transcoder
  -lEGL
  -lGLESv3
  -lpng
  -lz
  -lzstd
)