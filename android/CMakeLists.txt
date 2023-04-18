cmake_minimum_required(VERSION 3.4.1)  

include_directories(../ios/src)
include_directories(../ios/include)
include_directories(../ios/include/stb)
include_directories(src/main/cpp)
link_directories(src/main/jniLibs/${ANDROID_ABI}) 
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
add_library( 
            filament_interop
            SHARED
            src/main/cpp/filament_android.cpp
            ../ios/src/ktxreader/Ktx1Reader.cpp
            src/main/cpp/StbProvider.cpp
            src/main/cpp/JobSystem.cpp
            ../ios/src/SceneAssetLoader.cpp
            ../ios/src/FilamentViewer.cpp
            ../ios/src/PolyvoxFilamentApi.cpp
            ../ios/src/StreamBufferAdapter.cpp
            ../ios/src/image/imagematerial.c
            ../ios/src/shaders/unlitopaque.c
            ../ios/src/SceneAsset.cpp
        )

add_library(FILAMENT_SHADERS SHARED 
  ../ios/include/material/image.c
  ../ios/include/material/unlitopaque.c
)

target_link_libraries(
  filament_interop 
  FILAMENT_SHADERS
  -landroid 
  -llog 
  -lfilament 
  -lbackend 
  -lfilameshio 
  -lviewer 
  -lfilamat 
  -lgeometry 
  -lutils 
  -lfilabridge 
  -lgltfio_core 
  -lfilament-iblprefilter 
  -limage 
  -lcamutils 
  -lfilaflat 
  -ldracodec 
  -libl 
  -lktxreader 
  -limageio
  -lpng
  -ltinyexr
  -lz
  -lstb  
  -lEGL 
  -lGLESv3 
  -lbluevk 
  -lvkshaders 
  -luberzlib 
  -lsmol-v 
  -luberarchive 
  -lzstd
  )

