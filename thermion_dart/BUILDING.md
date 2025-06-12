# Instructions for building Filament

Below are instructions for building the Filament (currently pinned to v1.58.0) for each of the target platforms.

This is only for developers extending the Thermion package itself; if you are simply using Thermion as a dependency in your `pubspec.yaml`, you can ignore this.

## MacOS (arm64/x64)

```
mkdir -p out/cmake-release
cd out/cmake-release
./build.sh -l -i -f -p desktop release
./build.sh -l -i -f -t -d -p desktop debug # build with the framegraph viewer/material debug server enabled
```

(Currently we can't pass -DGLTFIO_USE_FILESYSTEM=0, but if/when we can, will look like this:)
```
cmake -G Ninja \
        "-DCMAKE_OSX_ARCHITECTURES=arm64;x86_64" \
        -DIMPORT_EXECUTABLES_DIR=out \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_INSTALL_PREFIX="../release/filament" \
        -DGLTFIO_USE_FILESYSTEM=0 \
        ../..
ninja
ninja install
```
# iOS

```
./build.sh -l -i -f -p ios release
cd out/cmake-ios-release-arm64/third_party
mkdir -p libz && cd libz
cmake -G Ninja -DIOS=1 -DIPHONEOS_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_BUILD_TYPE=Release  ../../../../third_party/libz
ninja
mkdir -p imageio && cd imageio
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
        -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
        -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out -DCMAKE_CXX_FLAGS="-I../../../../libs/image/include -I../../../../libs/utils/include -I../../../../libs/math/include -I../../../../third_party/tinyexr -I../../../../third_party/libpng -I../../../../third_party/basisu/encoder" \
        ../../../../libs/imageio
ninja
cd .. && mkdir -p tinyexr && cd tinyexr
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 \
        -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
        -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out -DCMAKE_CXX_FLAGS="-I../../../../libs/image/include -I../../../../libs/utils/include -I../../../../libs/math/include -I../../../../third_party/tinyexr -I../../../../third_party/libpng -I../../../../third_party/basisu/encoder" \
        ../../../../libs/tinyexr
./build.sh -l -i -f -p desktop debug 
```

## Android

```
./build.sh -i -f -p android release
./build.sh -i -f -t -d -p android debug # builds with the framegraph viewer/material debug server enabled
for file in libimageio.a libtinyexr.a; do for arch in arm64-v8a armeabi-v7a x86_64 x86; do cp /Volumes/T7/v1.51.2/android/release/$arch/$file ~/Documents/thermion/thermion_dart/.dart_tool/thermion_dart/lib/v1.58.0/android/debug/$arch/; done; done
cd out/android-release/filament/lib/ && zip -r filament-v1.58.0-android-release.zip  arm* x86* && rclone copy filament-v1.58.0-android-release.zip thermion:thermion/
cd out/android-debug/filament/lib/ && zip -r filament-v1.58.0-android-debug.zip  arm* x86* && rclone copy filament-v1.58.0-android-debug.zip thermion:thermion/ 
```

## Windows

- Install Visual Studio 2022
- Open Developer Command Prompt 

```
where cmake
```

(If multiple entries appear, you'll need to refer to the VS2022 version explicitly)


```
mkdir out; 
cd out
cmake -DUSE_STATIC_CRT=OFF -DFILAMENT_SUPPORTS_VULKAN=ON -DFILAMENT_SKIP_SAMPLES=ON -DCMAKE_BUILD_TYPE=Release -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF ..\..
cmake --build . --config Release
cmake --build . --target tinyexr --config Release
cmake --build . --target imageio --config Release
cmake --build . --config Debug
```

# Web

By default, Filament WASM builds are single-threaded with no support for `-pthread` (`WEBGL_PTHREADS=0`).

This won't work with our current implementation, since at least `-pthread` is needed to support running Filament on a dedicated (non-main) render thread.

However, the multi-threaded Filament WASM build (`WEBGL_PTHREADS=1`, which sets `-pthread`) doesn't work with our current setup (which uses an OffscreenCanvas without proxying, effectively locking the context to a single thread).

To work around, we need to adjust the Filament build configuration to build:
1) a single-threaded library
2) but with `-pthread` enabled

 
```
./build.sh -p desktop release
mkdir -p out/cmake-webgl-release
cd out/cmake-webgl-release
ln -s ../cmake-release/tools
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DWEBGL=1 \
        -DWEBGL_PTHREADS=0 \
        -DFILAMENT_SKIP_SAMPLES=1 \
        -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
        -DCMAKE_TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
        -DCMAKE_C_FLAGS="-pthread" \
        -DCMAKE_CXX_FLAGS="-pthread" \
        -DIS_HOST_PLATFORM=0 -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out \
        ../../ 
ninja;
cd libs
mkdir imageio
cd imageio
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DFILAMENT_SKIP_SAMPLES=1 \
        -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
        -DCMAKE_TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
        -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
        -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory" \
        -DZ_HAVE_UNISTD_H=1 -DUSE_ZLIB=1 -DIMPORT_EXECUTABLES_DIR=out -DCMAKE_CXX_FLAGS="-I../../../../libs/image/include -I../../../../libs/utils/include -I../../../../libs/math/include -I../../../../third_party/tinyexr -I../../../../third_party/libpng -I../../../../third_party/basisu/encoder" \
        ../../../../libs/imageio
ninja
cd ..
mkdir third_party/
cd third_party/
#find . -type f -exec file {} \; | grep "text" | cut -d: -f1 | xargs dos2unix
# for zlib, replace this:
#-   set_target_properties(zlib zlibstatic PROPERTIES OUTPUT_NAME z)
# with this:
#+   set_target_properties(zlib PROPERTIES OUTPUT_NAME z)
# libz 
#sed -i 's/set_target_properties(zlib zlibstatic PROPERTIES OUTPUT_NAME z)/set_target_properties(zlib PROPERTIES OUTPUT_NAME z)\n set_target_properties(zlibstatic PROPERTIES OUTPUT_NAME zstatic)/#g' ../../../../third_party/libz/CMakeLists.txt
mkdir -p libz;
pushd libz;
lib=libz
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
        -DCMAKE_C_FLAGS="-pthread -matomics -mbulk-memory" \
        -DCMAKE_CXX_FLAGS="-pthread -matomics -mbulk-memory" \
        ../../../../third_party/$lib;
ninja
popd
for lib in tinyexr libpng; do 
    mkdir -p $lib;
    pushd $lib;
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
        -DCMAKE_C_FLAGS="-pthread -I../libz" \
        -DCMAKE_CXX_FLAGS="-pthread -I../libz -matomics -mbulk-memory" \
        -DPNG_SHARED=OFF \
        -DZLIB_ROOT=../../../../third_party/libz \
        -DZLIB_LIBRARY=../../../../third_party/libz/libz.a \
        -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
        ../../../../third_party/$lib;
    ninja;
    popd; 
done