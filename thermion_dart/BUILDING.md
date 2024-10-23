# Instructions for building Filament

Below are instructions for building the Filament (currently pinned to v1.51.2) for each of the target platforms.

This is only for developers extending the Thermion package itself; if you are simply using Thermion as a dependency in your `pubspec.yaml`, you can ignore this.

## Windows

- Install Visual Studio 2022
- Open Developer Command Prompt 

> where cmake

(If multiple entries appear, you'll need to refer to the VS2022 version explicitly)

> mkdir out; 
> cd out
> cmake -DUSE_STATIC_CRT=OFF ..
> cmake --build . --config Release
> cmake --build . --target tinyexr --config Release
> cmake --build . --target imageio --config Release