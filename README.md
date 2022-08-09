# polyvox_filament

Flutter plugin wrapping the Filament renderer https://github.com/google/filament.

Current Filament version: 1.25.0

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


