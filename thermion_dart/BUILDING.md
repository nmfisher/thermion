# Instructions for building Filament

Below are instructions for building the Filament (currently pinned to v1.58.0) for each of the target platforms.

This is only for developers extending the Thermion package itself; if you are simply using Thermion as a dependency in your `pubspec.yaml`, you can ignore this.

## MacOS (arm64/x64)

```
./build.sh -l -i -f -p desktop release
./build.sh -l -i -f -t -d -p desktop debug # build with the framegraph viewer/material debug server enabled
```

# iOS

```
./build.sh -l -i -f -p ios release
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
