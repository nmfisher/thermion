# polyvox_filament


Flutter plugin wrapping the Filament renderer https://github.com/google/filament.

Filament is bundled with pre-compiled static libraries:

iOS/MacOS: v1.43.1
(iOS release build has a skybox bug so the debug versions are currently shipped on iOS)
Windows - v1.32.4
(Waiting for https://github.com/google/filament/issues/7078 to be resolved before upgrading, not sure exactly when the bug was introduced but it was somewhere between v1.34.2 and v1.40.0)
Linux - TODO, previously was v1.24.1 but this needs to be bumped up to parity with the other platforms (ideally v.1.43.1)

Only arm64 libs are provided for iOS/MacOS, only x64 libs are provided for Windows/Linux, all provided for Android.

Building notes:
- we remove -fno-exceptions from CMakeLists.txt 

Project structure:
- most shared code/headers under ios/src (because I still can't get podspec to build a target with symlinks or relative paths)
- building on MacOS, we currently just delete the macos/include and macos/src directories and copy from iOS  (for same reason), 
e.g.
`rm -r ../macos/include && cp -R ../ios/include ../macos && rm -r ../macos/src && cp -R ../ios/src ../macos && pushd macos && pod update && popd && flutter run -d macos`
- Android keeps a separate copy of ALL headers (because it's currently running a different version of Filament, earlier versions have some texture filtering issues) 
-- can't symlink either?
--- IMPORTANT - current version only works on Flutter 3.15.0-15.2.pre / Filament v1.43.1

- Note also need to specifically build imageio/png/tinyexr 
- if release build, then need to comment out -fno-exceptions

Linux specific

(Fedora 34)
Building Filament:
env LIBRARY_PATH=/usr/lib/gcc/x86_64-redhat-linux/11/ CC=clang CXX=clang++ CXX_FLAGS="-v" LD_FLAGS="-v" FILAMENT_REQUIRES_CXXABI=true  ./build.sh -c release

Running example project:
export PKG_CONFIG_PATH=/usr/lib/pkgconfig/:/usr/lib64/pkgconfig/ CPLUS_INCLUDE_PATH=/usr/include/gtk-3.0/:/usr/include/pango-1.0/:/usr/include/harfbuzz:/usr/include/cairo/:/usr/include/gdk-pixbuf-2.0/:/usr/include/atk-1.0/

Extract and move both lib/ and include/ to ./ios

Web:

EMCC_CFLAGS="-Wno-missing-field-initializers -Wno-deprecated-literal-operator -fPIC" ./build.sh -c -p webgl -i debug

EMCC_CFLAGS="-I/Users/nickfisher/Documents/filament/libs/utils/include -I/Users/nickfisher/Documents/filament/libs/image/include -I/Users/nickfisher/Documents/filament/libs/math/include -I../../..//third_party/basisu/encoder/ -I../../..//third_party/libpng/ -I../../..//third_party/tinyexr/ -fPIC" emmake make

# Running

## Android 

- MainActivity.kt must have the following:
```
class MainActivity: FlutterActivity() {
    override fun getTransparencyMode(): TransparencyMode {
        return TransparencyMode.transparent
    }
}
```
and theme must have the following in `styles.xml`
```
<style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowBackground">@android:color/transparent</item>
</style>
```

Remember to set the background colour for your Scaffold to transparent!

Materials

- there is a simple material (unlit/opaque) used for background images. This is created by:
```
filament/out/release/filament/bin/matc -a opengl -a metal -o materials/image.filamat materials/image.mat
filament/out/release/filament/bin/resgen -c -p image -x ios/include/material/ materials/image.filamat            
```
 



