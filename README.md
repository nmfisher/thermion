# Flutter Filament

Cross-platform, 3D PBR rendering and animation for [Flutter](https://github.com/google/filament).

Wraps the [the Filament rendering library](https://github.com/google/filament).

Powers the [Polyvox](https://polyvox.app) and [odd-io](https://github.com/odd-io/) engines.

This is still in beta: bugs/missing features are to be expected.

https://github.com/nmfisher/polyvox_filament/assets/7238578/abaed1c8-c97b-4999-97b2-39e85e0fa7dd


|Feature|Supported|
|---|---|
|Platforms|✅ iOS (arm64)<br/>✅ MacOS (arm64)<br/>✅ Android (arm64) <br/>✅ Windows (x64)<br/>⚠️ Linux (x64 - broken)<br/>⚠️ Web (planned)|
|Formats|✅ glb <br/>⚠️ glTF (partial - see Known Issues)|
|Texture support|✅ PNG <br/>✅ JPEG <br/>✅ KTX <br/>⚠️ KTX2 (planned)|
|Camera movement|✅ Desktop (mouse)<br/>✅ Mobile (swipe/pinch)|
|Animation|✅ Embedded glTF skinning animations<br/>✅ Embedded glTF morph animations<br/> ✅ Runtime/dynamic morph animations<br/> ⚠️ Runtime/dynamic skinning animations <br/>
|Entity manipulation|✅ Viewport selection<br/>⚠️ Entity/transform parenting (planned)<br/> ⚠️ Transform manipulation (mouse/gesture to rotate/translate/scale object) (partial)<br/>⚠️ Runtime material changes (planned)|

Special thanks to [odd-io](https://github.com/odd-io/) for sponsoring work on supporting Windows, raycasting, testing and documentation.

PRs are welcome but please create a placeholder PR to discuss before writing any code. This will help with feature planning, avoid clashes with existing work and keep the project structure consistent.   

## Getting Started

This package requires Flutter >= `3.16.0-0.2.pre`, so you will need to first switch to the `beta` channel: 

```
flutter channel beta
flutter upgrade
```
There are specific issues with earlier versions on Windows/MacOS (mobile should actually be fine, so if you want to experiment on your own you're free to remove the minimum version from `pubspec.yaml`).

Next, clone this repository and pull the latest binaries from Git LFS:

```
cd $HOME
git clone <repo> && cd flutter_filament
git lfs pull
```

(this step won't be needed after the plugin is published to pub.dev).

> You *do not need to build Filament yourself*. The repository is bundled with all necessary headers/static libraries (`windows/lib`, `ios/lib`, `macos/lib` and `linux/lib`) and the Flutter plugin has been configured to link at build time.

Run the example project to check:

```
cd example && flutter run -d <macos/windows/Your iPhone/etc>
```

To use the plugin in your own project, add the plugin to your pubspec.yaml:

```
name: your_project
description: Your project
...
dependencies:
  flutter:
    sdk: flutter
  flutter_filament:
      path: <path where you cloned the repository>      
```

## Basic Usage

See the `example` project for a complete sample that incorporates many of the below steps, and more.

### Creating the viewport widget and controller

Create an instance of `FilamentControllerFFI` somewhere in your app where it will not be garbage collected until you no longer need a rendering canvas:

```
class MyApp extends StatelessWidget {

    final _filamentController = FilamentControllerFFI();
    ...
}

```

This is a relatively lightweight object, however its constructor will load/bind symbols from the native library. This may momentarily block the UI, so you may wish to structure your app so that this is hidden behind a static widget until it is available.

Next, create an instance of `FilamentWidget` in the widget hierarchy where you want the rendering canvas to appear. This can be sized as large or as small as you want. Flutter widgets can be positioned above or below the `FilamentWidget`.

```
class MyApp extends StatelessWidget {
    
    final _filamentController = FilamentControllerFFI();

    @override
    Widget build(BuildContext context) {
     return MaterialApp(
        color: Colors.white,
        home: Scaffold(backgroundColor: Colors.white, body: Stack(children:[
            Container(color:Colors.green, height:100, width:100),
            Positioned.fill(top:100, left:100child:FilamentWidget(controller:_filamentController)),
            Positioned(right:0, bottom:0, child:Container(color:Colors.purple, height:100, width:100))
        ])));
    }
}
```

When a `FilamentWidget` is added to the widget hierarchy:
1) on the first frame, by default a Container will be rendered with solid red. If you want to change this, pass a widget as the `initial` paramer to the `FilamentWidget` constructor.
2) on the second frame, `FilamentWidget` will retrieve its actual size and request the `FilamentController` to create:
    * the backing textures needed to insert a `Texture` widget into 
    * a rendering thread 
    * a `FilamentViewer` and an `AssetManager`, which will allow you to load assets/cameras/lighting/etc via the `FilamentController`
3) after an indeterminate number of frames, `FilamentController` will notify `FilamentWidget` when a texture is available the viewport 
4) `FilamentWidget` will replace the default `initial` Widget with the viewport (which will initially be solid black or white, depending on your platform).

It's important to note that there *will* be a delay between adding a `FilamentWidget` and the actual rendering viewport becoming available. This is why we fill `FilamentWidget` with red - to make it abundantly clear that you need to handle this asynchronous delay appropriately.  You can call `await _filamentController.isReadyForScene` if you need to wait until the viewport is actually ready for rendering.

> Currently, the `initial` widget will also be displayed whenever the viewport is resized (including changing orientation on mobile and drag-to-resize on desktop). You probably want to change this from the default red.


Congratulations! You now have a scene. It's completely empty, so you probably want to add.

### Load a background

You probably want to set a background for your scene. You can load a skybox:
```
await _filamentController.loadSkybox("assets/default_env/default_env_skybox.ktx)
```

or a static background image:

```
await _filamentController.setBackgroundImage("assets/background.ktx)
```

or a solid background color:

```
await _filamentController.setBackgroundColor(0.0, 1.0, 0.0, 1.0); // solid green
```

At this point, you might not see any change in the viewport. This is because the FilamentController will only actually render into the viewport once `render` has been called.

By default, the FilamentController will only render into the viewport by manually calling `render()` on the FilamentController. This is to avoid needlessly running a render loop when there is nothing to display.

```
await _filamentController.render()
```

You should now see your background displayed in the scene. To automatically render at 60fps, call `setRendering`:
```
await _filamentController.setRendering(true);
```

### Load an asset

To add a glTF asset to the scene, call `loadGlb()` on `FilamentController` with the Flutter asset path to your .glb file.

For example, if your `pubspec.yaml` looks like this:
```
flutter:
  assets:
    - assets/models/bob.glb
```

Then you would call the following
```
var entity = await _filamentController.loadGlb("assets/models/bob.glb");
```
You can also pass a URI to indicate that the glTF file should be loaded from the filesystem:
```
var entity = await _filamentController.loadGlb("file:///tmp/bob.glb");
```

The return type `FilamentEntity` is simply an integer handle that be used to manipulate the entity in the scene. For example, to remove the asset:
```
await _filamentController.removeAsset(entity);
entity = null; 
``` 
> Removing an entity from the scene will invalidate the corresponding `FilamentEntity` handle, so ensure you don't retain any references to it after calling `removeAsset` or `clearAssets`. Removing one `FilamentEntity` does not invalidate/change any other `FilamentEntity` handles; you can continue to safely manipulate these via the `FilamentController`.

### Lighting

You should now see your object in the viewport, but since we haven't added a light, this will be solid black.

Add an image-based light from a KTX file:

```
await _filamentController.loadIbl("assets/default_env/default_env_ibl.ktx");
```

You can also add dynamic lights:

```
var sun = await _filamentController.addLight(
```

### Manipulating entity transforms

To set the world space position of the asset:
```
_filamentController.setPositon(entity, 1.0, 1.0, 1.0);
```

On desktop, you can also click any renderable object in the viewport to retrieve its associated FilamentEntity (see below).

### Camera movement

To enable mouse/swipe navigation through the scene, wrap the `FilamentWidget` inside a `FilamentGestureDetector`:

```
class MyApp extends StatelessWidget {
    
    final _filamentController = FilamentControllerFFI();

    @override
    Widget build(BuildContext context) {
     return MaterialApp(
        color: Colors.white,
        home: Scaffold(backgroundColor: Colors.white, body: Stack(children:[
            Positioned.fill(child:FilamentGestureDetector(
                controller: _filamentController,
                child:FilamentWidget(
                    controller:_filamentController
                ))),
            Positioned(right:0, bottom:0, child:Container(color:Colors.purple, height:100, width:100))
        ])));
    }
}
```

On desktop:
1) hold the middle mouse button and move the mouse to rotate the camera
2) hold the left mouse button and move the mouse to pan the camera
3) scroll up/down with the scrollwheel to zoom in/out.

On mobile:
1) swipe with your finger to pan the camera
2) double tap the viewport, then swipe with your finger to rotate the camera (double-tap again to return to pan)
3) pinch with two fingers in/out to zoom in/out.

### Changing the active camera 

Every scene has a default camera. Whenever you rotate/pan/zoom the viewport, you are moving the default camera.

If you have added an entity to the scene that contains one or more camera nodes, you can change the active scene camera to one of those camera nodes.

```
var asset = await _filamentController.loadGlb("assets/some_asset_with_camera.glb");
await _filamentController.setCamera(asset, "Camera.002"); // pass the node name to load a specific camera under that entity node
await _filamentController.setCamera(asset, null); // pass null to load the first camera found under that entity
```

### Picking entities

On desktop, left-clicking an object in the viewport will retrieve the FilamentEntity for the top-most renderable instance at that cursor position (if any).

Note this is an asynchronous operation, so you will need to subscribe to the [pickResult] stream on your [FilamentController] to do something with the result.

```
class MyApp extends StatefulWidget {
    ...
}


class _MyAppState extends State<MyApp> {
    
    final _filamentController = FilamentControllerFFI();

    @override
    void initState() { 
        _filamentController.pickResult.listen((FilamentEntity filamentEntity) async {
            var entityName = _filamentController.getNameForEntity(filamentEntity);
            await showDialog(builder:(ctx) {
                return Container(child:Text("You clicked $entityName"));
            });
        });
    }

    @override
    Widget build(BuildContext context) {
     return MaterialApp(
        color: Colors.white,
        home: Scaffold(backgroundColor: Colors.white, body: Stack(children:[
            Positioned.fill(child:FilamentGestureDetector(
                controller: _filamentController,
                child:FilamentWidget(
                    controller:_filamentController
                ))),
        ])));
    }
}
```

## Advanced Usage

If you want to work with custom materials, you will need some (basic knowledge of the underlying Filament library)[https://google.github.io/filament/Materials.html#compilingmaterials].

Things to keep in mind:
- You must compile materials with the correct version of Filament (see the table above). Keep in mind that versions may not be identical across platforms so you may need multiple uberz files for multiple platforms.

e.g. the lit_opaque.uberz file has been created from a Filament build:

```
cd out/cmake-android-release-aarch64/libs/gltfio
uberz -TSHADINGMODEL=lit -TBLENDING=opaque -o lit_opaque_43.uberz lit_opaque 
```

(note that the number in the filename corresponds to the Material version, not the Filament version. Not every Filament version requires a new Material version).

## Footguns

### Stripping in release mode

If you build your app in release mode, you will need to ensure that "Dead Strip" is set to false.

This is because we only invoke the library at runtime via FFI, so at link time these symbols are otherwise treated as redundant.

### Animations when backgrounded

Don't call playAnimation when the app is in the background  (i.e inactive/hidden). This will queue, but not start, an animation, and eventually this will overflow the command buffer when the app is foregrounded/resumed.

If you have some kind of looping animation in your app code, make sure it pauses while the app is backgrounded.



## Versioning

||Android|iOS|MacOS|Windows|Linux|WebGL|
|---|---|---|---|---|---||
|Filament|v1.43.1 (arm64/armeabi-v7a/x86/x86_64)|v1.43.1* (arm64)|v1.43.1 (arm64)|v1.32.4 (x86_64)|TODO**|TODO***|
|Flutter||3.15.0-15.2.pre|3.15.0-15.2.pre|3.15.0-15.2.pre

* iOS release build has a skybox bug so the debug versions are currently shipped on iOS
** (Waiting for https://github.com/google/filament/issues/7078 to be resolved before upgrading, not sure exactly when the bug was introduced but it was somewhere between v1.32.4 and v1.40.0)
*** Texture widget not currently supported on web in Flutter. 


## Testing

We automate testing by running the example project on actual iOS/Android/MacOS/Windows devices and executing various operations.

Eventually we want to compare screenshots after each operation to a set of goldens for every platform.

Currently this is only possible on iOS (see https://github.com/flutter/flutter/issues/123063 and https://github.com/flutter/flutter/issues/127306).

To re-generate the golden screenshots for a given device:

```
./regenerate_goldens.sh <your_device_id>
```
To run the tests and compare against those goldens:
```
./compare_goldens.sh <your_device_id>
```

The results will depend on the actual device used to generate the golden, therefore if you are using a different device (which is likely), your results may not be the same. This is expected.

# Building Filament from source

```
git clone git@github.com:nmfisher/filament.git && cd filament
```

## Android/iOS/MacOS

```
git checkout flutter-filament-ios-android-macos
./build.sh -p <platform> release
```

## Windows

To support embedding GPU textures in Flutter (rather than copying to a CPU pixel buffer on every frame), we need to build a slightly customized version of Filament that uses GLES on Windows (rather than the default, which uses OpenGL).

Separately, we also force the Filament gltfio library to load assets via in-memory buffers, rather than the filesystem. This is simply a convenience so we don't have to use different logic for gltf resource loading across platforms.

```
git checkout flutter-filament-windows
mkdir out && cd out
"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" --build . --target gltf_viewer --config Debug
```

Building notes:
On Android/iOS, we remove -fno-exceptions from CMakeLists.txt 

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

# Linux specific

(Fedora 34)
Building Filament:
env LIBRARY_PATH=/usr/lib/gcc/x86_64-redhat-linux/11/ CC=clang CXX=clang++ CXX_FLAGS="-v" LD_FLAGS="-v" FILAMENT_REQUIRES_CXXABI=true  ./build.sh -c release

Running example project:
export PKG_CONFIG_PATH=/usr/lib/pkgconfig/:/usr/lib64/pkgconfig/ CPLUS_INCLUDE_PATH=/usr/include/gtk-3.0/:/usr/include/pango-1.0/:/usr/include/harfbuzz:/usr/include/cairo/:/usr/include/gdk-pixbuf-2.0/:/usr/include/atk-1.0/

Web:

EMCC_CFLAGS="-Wno-missing-field-initializers -Wno-deprecated-literal-operator -fPIC" ./build.sh -c -p webgl -i debug

EMCC_CFLAGS="-I/Users/nickfisher/Documents/filament/libs/utils/include -I/Users/nickfisher/Documents/filament/libs/image/include -I/Users/nickfisher/Documents/filament/libs/math/include -I../../..//third_party/basisu/encoder/ -I../../..//third_party/libpng/ -I../../..//third_party/tinyexr/ -fPIC" emmake make


## Materials

We use a single material (no lighting and no transparency) for background images:
```
filament/out/release/filament/bin/matc -a opengl -a metal -o materials/image.filamat materials/image.mat
filament/out/release/filament/bin/resgen -c -p image -x ios/include/material/ materials/image.filamat            
```

# Known issues

On Windows, loading a glTF (but NOT a glb) may crash due to a race condition between uploading resource data to GPU memory and being freed on the host side.

This has been fixed in recent versions of Filament, but other bugs on Windows prevent upgrading.

Only workaround is to load a .glb file.
