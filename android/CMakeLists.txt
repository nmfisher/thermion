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
            src/main/cpp/KtxReader1.cpp
            src/main/cpp/StbProvider.cpp
            src/main/cpp/JobSystem.cpp
            ../ios/src/SceneAssetLoader.cpp
            ../ios/src/FilamentViewer.cpp
            ../ios/src/StreamBufferAdapter.cpp
            ../ios/src/image/imagematerial.c
            ../ios/src/SceneAsset.cpp
        )

target_link_libraries(
  filament_interop 
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

