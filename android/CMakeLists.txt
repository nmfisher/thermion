cmake_minimum_required(VERSION 3.10)  

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(../ios/include/filament)
include_directories(src/main/cpp)
link_directories(src/main/jniLibs/${ANDROID_ABI}) 
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")

add_library(polyvox_filament_android SHARED
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/PolyvoxFilamentApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/PolyvoxFilamentFFIApi.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/FilamentAndroid.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/AssetManager.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/FilamentViewer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/StreamBufferAdapter.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/TimeIt.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/camutils/Manipulator.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/src/camutils/Bookmark.cpp"
)

add_library(FILAMENT_SHADERS SHARED 
  "${CMAKE_CURRENT_SOURCE_DIR}/../ios/include/material/image.c"
)

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
  -lGLESv3
  -lEGL
  -lpng
  -lz
  -lzstd
)