# Instructions for building Filament

```
# platform=linux builds BOTH x86_64 (ubuntu-24.04) and arm64 (ubuntu-24.04-arm),
# producing filament-<version>-linux-{release,debug}.zip and
# filament-<version>-linux-arm64-{release,debug}.zip on R2.
gh workflow run "Build Filament" --ref filament/v1.74.0 -f platform=linux -f clean_build=false -f upload_to_r2=true
gh workflow run "Build Filament" --ref filament/v1.74.0 -f platform=android -f clean_build=false -f upload_to_r2=true 
gh workflow run "Build Filament" --ref filament/v1.74.0 -f platform=windows -f clean_build=false -f upload_to_r2=true
gh workflow run "Build Filament" --ref filament/v1.74.0 -f platform=macos -f clean_build=false -f upload_to_r2=true
```

Below are instructions for building the Filament (currently pinned to v1.74.0) for each of the target platforms.

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

## Linux (x64)

Edit `third_party/basisu/tnt/CMakeLists.txt`:
```
project(basisu)
set(CMAKE_POSITION_INDEPENDENT_CODE ON) // ADD THIS LINE 
```

```
./build.sh -l -i -f -p desktop release
./build.sh -l -i -f -p desktop release zstd
./build.sh -l -i -f -p desktop release tinyexr
./build.sh -l -i -f -p desktop release imageio
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
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DPLATFORM_NAME="iphonesimulator" \
        -DZLIB_INCLUDE_DIR=../../../../third_party/libz \
        -DZ_HAVE_UNISTD_H=1 
        -DUSE_ZLIB=1
        -DIMPORT_EXECUTABLES_DIR=out 
        -DCMAKE_CXX_FLAGS="-I../../../../libs/image/include 
        -I../../../../libs/utils/include 
        -I../../../../libs/math/include 
        -I../../../../third_party/tinyexr 
        -I../../../../third_party/libpng 
        -I../../../../third_party/basisu/encoder" \
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
for file in libimageio.a libtinyexr.a; do for arch in arm64-v8a armeabi-v7a x86_64 x86; do cp /Volumes/T7/v1.51.2/android/release/$arch/$file ~/Documents/thermion/thermion_dart/.dart_tool/thermion_dart/lib/v1.74.0/android/debug/$arch/; done; done
cd out/android-release/filament/lib/ && zip -r filament-v1.74.0-android-release.zip  arm* x86* && rclone copy filament-v1.74.0-android-release.zip thermion:thermion/
cd out/android-debug/filament/lib/ && zip -r filament-v1.74.0-android-debug.zip  arm* x86* && rclone copy filament-v1.74.0-android-debug.zip thermion:thermion/ 
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

### Debug artifacts and `mode: debug`: matdbg / fgviewer (Windows checklist)

The hook links Filament's debug-server archives — `matdbg` (material debugger) and
`fgviewer` (frame-graph viewer) — whenever `libfilament` was built with them enabled.
That is a property of the **artifact**, not of the build mode alone:

| Debug zip | `FILAMENT_ENABLE_MATDBG` / `_FGVIEWER` | `filament` references them | ships `matdbg` / `fgviewer` |
|---|---|---|---|
| macOS, Linux, Android (`build_*.sh -t -d`) | ON / ON | yes | yes / yes |
| iOS | OFF / OFF | no | no / no |
| Windows (`build_windows.bat` passes neither option) | OFF / OFF | no | yes / **no** |

So the hook links both archives unconditionally on macOS/Linux/Android (a missing
archive must fail the link, not dlopen), and **by presence** on Windows: an archive
is linked only if the zip contains its `.lib` (the hook logs any skip). With the
pinned v1.77.2 Windows zip that means `matdbg` is linked and `fgviewer` is skipped;
since `filament.lib` references neither, the linker extracts no member from
`matdbg.lib` and `libthermion_dart.dll` does not grow. Whenever `matdbg` is linked
the hook also adds what it references on Windows, where nothing is folded into
combined archives: `matdbg_resources`, `civetweb`, `SPIRV-Tools`, `spirv-cross-core`,
`spirv-cross-glsl`, `filamat` and the shader-compiler split below, and it defines
`ENABLE_MATDBG=1` for thermion's own sources (nothing consumes it yet).

Windows debug artifacts carry glslang's CMake `DEBUG_POSTFIX`: `OSDependentd.lib`,
`glslangd.lib`, `SPIRVd.lib` instead of the release `OSDependent.lib`, `glslang.lib`,
`SPIRV.lib`. The hook picks the names from the build mode; `runtime_materials: true`
in a debug build needs the suffixed names too (the release names do not exist in the
debug zip, and vice versa).

**To get the debug server on Windows for real**, `scripts/build_windows.bat` has to
configure a *separate* Debug CMake tree with `-DFILAMENT_ENABLE_MATDBG=ON
-DFILAMENT_ENABLE_FGVIEWER=ON` (the Visual Studio generator is multi-config, so one
tree cannot enable them for Debug only), build `--config Debug` there, upload the
zip and re-pin `windows/debug` in `filament.libs.json`. No hook change is needed:
`fgviewer.lib` is linked as soon as the zip ships it (its own dependencies have not
been inspected — no artifact ships it). The zips also contain no `matdbg/` headers,
so thermion code cannot `#include <matdbg/...>` yet.

#### Windows runner checklist for a `mode: debug` build

1. **Libs in the zip.** The debug zip must contain every `.lib` the hook names for
   this configuration: `matdbg.lib`, `matdbg_resources.lib`, `civetweb.lib`,
   `filamat.lib`, `glslangd.lib`, `SPIRVd.lib`, `OSDependentd.lib`, `SPIRV-Tools.lib`,
   `spirv-cross-core.lib`, `spirv-cross-glsl.lib`, plus the regular Windows set. A
   missing file fails with `LNK1181: cannot open input file`. The hook's cache
   directory is the `Searching for Filament libraries under ...` line in `build.log`.
   ```powershell
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   [IO.Compression.ZipFile]::OpenRead("<cache dir>\filament-v1.77.2-windows-debug-115171555c6d3c2e.zip").Entries.FullName
   ```
2. **No LNK2005.** On Linux both `libmatdbg.a` and `libfgviewer.a` bundle civetweb,
   so force-loading both gives duplicate `mg_*` definitions (ticket the-c8d3). On
   Windows nothing is bundled — `civetweb.lib` is its own input — and CBuilder
   emits the `libraries` list as plain `matdbg.lib fgviewer.lib`
   (no `/WHOLEARCHIVE`), so the linker extracts only members that something
   references. `LNK2005 ... already defined in civetweb.obj` means a
   `/WHOLEARCHIVE:matdbg.lib` (or `fgviewer.lib`) has crept onto the link line.
3. **CRT match.** The hook compiles with `/MDd` and `_DEBUG` in debug mode. The
   pinned debug archive was built with `-MDd`; its objects carry
   `/FAILIFMISMATCH:"RuntimeLibrary=MDd_DynamicDebug"`,
   `/FAILIFMISMATCH:"_ITERATOR_DEBUG_LEVEL=2"` and `/DEFAULTLIB:"MSVCRTD"`. A
   mismatch fails with `LNK2038`. Check the artifact side with
   `dumpbin /directives filament.lib | findstr /i "RuntimeLibrary ITERATOR DEFAULTLIB"`.
4. **Result.** The link completes with no `LNK1181`, `LNK2001`, `LNK2005` or
   `LNK2038`, and `libthermion_dart.dll` is about the same size as before the
   debug-server inputs were added (no `matdbg` member is extracted while the
   artifact is built with `FILAMENT_ENABLE_MATDBG=0`).

# Web

By default, Filament WASM builds are single-threaded with no support for `-pthread` (`WEBGL_PTHREADS=0`).

This won't work with our current implementation, since at least `-pthread` is needed to support running Filament on a dedicated (non-main) render thread.

However, the multi-threaded Filament WASM build (`WEBGL_PTHREADS=1`, which sets `-pthread`) doesn't work with our current setup (which uses an OffscreenCanvas without proxying, effectively locking the context to a single thread).

To work around, we need to adjust the Filament build configuration to build:
1) a single-threaded library
2) but with `-pthread` enabled

 
```
./build.sh -p desktop release
mkdir -p out/cmake-webgl-release && cd out/cmake-webgl-release
ln -s ../cmake-release/tools
cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DWEBGL=1 \
        -DWEBGL_PTHREADS=0 \
        -DCMAKE_CXX_STANDARD=20 \
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
        -DCMAKE_CXX_STANDARD=20 \
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
        -DCMAKE_CXX_STANDARD=20 \
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