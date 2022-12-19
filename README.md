# polyvox_filament

Flutter plugin wrapping the Filament renderer https://github.com/google/filament.

Current Filament version: 112366e54524149e3a5cc601067280766efe06df

All:
- clone Filament repository 
- copy filament/include to ios/include
- copy filament/libs/utils/include to ios/include

(even though headers are under the iOS directory these are used across all platforms).

Android:
- build from Filament repository on Linux (build native, then build Android). Reminder that NDK >= 24 required.
- need to specifically move imageio/png/tinyexr 
- if release build, then need to comment out -fno-exceptions
- copy out/android-release/filament/lib to android/src/main/jniLibs

iOS:
- filament-v1.25.0-ios.tgz

Linux:

(Fedora 34)
Building Filament:
env LIBRARY_PATH=/usr/lib/gcc/x86_64-redhat-linux/11/ CC=clang CXX=clang++ CXX_FLAGS="-v" LD_FLAGS="-v" FILAMENT_REQUIRES_CXXABI=true  ./build.sh -c release

Running example project:
export PKG_CONFIG_PATH=/usr/lib/pkgconfig/:/usr/lib64/pkgconfig/ CPLUS_INCLUDE_PATH=/usr/include/gtk-3.0/:/usr/include/pango-1.0/:/usr/include/harfbuzz:/usr/include/cairo/:/usr/include/gdk-pixbuf-2.0/:/usr/include/atk-1.0/

Extract and move both lib/ and include/ to ./ios

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


