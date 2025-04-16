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
cmake -DUSE_STATIC_CRT=OFF -DFILAMENT_SUPPORTS_VULKAN=ON -DFILAMENT_SKIP_SAMPLES=ON -DCMAKE_BUILD_TYPE=Release ..\..
cmake --build . --config Release
cmake --build . --target tinyexr --config Release
cmake --build . --target imageio --config Release
cmake --build . --config Debug
```