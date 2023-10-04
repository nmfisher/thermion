# Flutter Filament

Cross-platform, Physically-based rendering inside Flutter applications.

Flutter plugin wrapping the Filament renderer https://github.com/google/filament.

Powers the Polyvox and odd-io engines.

# Sponsors

Thank you to odd-io for sponsoring work on supporting Windows, raycasting, testing and documentation.

# Overview

## Versioning

Last tested on Flutter `3.15.0-15.2.pre`. This is on the Flutter beta channel, so run:
```
flutter channel beta
flutter upgrade
```

||Android|iOS|MacOS|Windows|Linux|WebGL
|---|---|---|---|---|---||
|Filament|v1.43.1 (arm64/armeabi-v7a/x86/x86_64)|v1.43.1* (arm64)|v1.43.1 (arm64)|v1.32.4 (x86_64)|TODO**|TODO***|
|Flutter||3.15.0-15.2.pre|3.15.0-15.2.pre|3.15.0-15.2.pre

* iOS release build has a skybox bug so the debug versions are currently shipped on iOS
** (Waiting for https://github.com/google/filament/issues/7078 to be resolved before upgrading, not sure exactly when the bug was introduced but it was somewhere between v1.32.4 and v1.40.0)
*** Texture widget not currently supported on web in Flutter. 

## Features

|Feature|Supported|
|---|---|
|glTF|Y|
|glb|Y|

# Basic Setup

## Clone flutter_filament 

This plugin is not yet published to pub.dev. To use in your project, simply clone the repository and pull the latest binaries from Git LFS:

```
cd $HOME
git clone <repo> && cd flutter_filament
git lfs pull
```

You *do not need to build Filament yourself*. The repository is bundled with all necessary headers/static libraries (`windows/lib`, `ios/lib`, `macos/lib` and `linux/lib`) and the Flutter plugin has been configured to link at build time.

If you want to run the example project to check:

```
cd example && flutter run -d <macos/windows/Your iPhone/etc>
```

## Add dependency

Add the plugin as a dependency in the pubspec.yaml for your application:

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

# Basic Usage

See the `example` project for a complete sample of the below steps.

## Creating the viewport widget and controller

To embed a viewport in your app, create an instance of `FilamentControllerFFI` somewhere in your app:

e.g.
```
class MyApp extends StatelessWidget {

    final _filamentController = FilamentControllerFFI();
    ...
}

```
Constructing this object only load symbols from the native FFI library. 

(Note this is not (yet) a singleton, so ensure it is placed somewhere in the widget hierachy where it will not be garbage-collected until you no longer need a rendering canvas).

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
a) the backing textures needed to insert a `Texture` widget into 
b) a rendering thread 
c) a `FilamentViewer` and an `AssetManager`, which will allow you to load assets/cameras/lighting/etc via the `FilamentController`

If this was successful, the viewport should turn from red to black.

### Rendering

By default, the FilamentController will only render into the viewport by manually calling `render()` on the FilamentController. This is to avoid needlessly running a render loop when there is nothing to display.

To automatically render at 60fps, call `setRendering(true)` on `FilamentController`.

### Assets

To add a glTF asset to the scene, call `loadGlb()` on `FilamentController` with the Flutter asset path to your .glb file.

For example, if your `pubspec.yaml` looks like this:
```
flutter:
  assets:
    - assets/models/bob.glb
```

Then you would call the following
```
var entity = _filamentController.loadGlb("assets/models/bob.glb");
```
You can also pass a URI to indicate that the glTF file should be loaded from the filesystem:
```
var entity = _filamentController.loadGlb("file:///tmp/bob.glb");
```

The returned value is an integer handle that be used to manipulate the asset (better referred to as the "entity") in the scene.

E.g. to remove the asset:
```
_filamentController.removeAsset(entity);
``` 

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
            Container(color:Colors.green, height:100, width:100),
            Positioned.fill(top:100, left:100,child:FilamentGestureDetector(
                controller: _filamentController,
                child:FilamentWidget(
                    controller:_filamentController
                ))),
            Positioned(right:0, bottom:0, child:Container(color:Colors.purple, height:100, width:100))
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



# Building Filament from source

```
git clone git@github.com:nmfisher/filament.git && cd filament
```

## Windows

To support embedding GPU textures in Flutter (rather than copying to a CPU pixel buffer on every frame), we need to build a slightly customized version of Filament that uses GLES on Windows (rather than the default, which uses OpenGL).

Separately, we also force the Filament gltfio library to load assets via in-memory buffers, rather than the filesystem. This is simply a convenience so we don't have to use different logic for gltf resource loading across platforms.

```
git checkout flutter-filament-windows
mkdir out && cd out
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

glTF assets The default 

- there is a simple material (unlit/opaque) used for background images. This is created by:
```
filament/out/release/filament/bin/matc -a opengl -a metal -o materials/image.filamat materials/image.mat
filament/out/release/filament/bin/resgen -c -p image -x ios/include/material/ materials/image.filamat            
```


# Known issues

On Windows, loading a glTF (but NOT a glb) may crash due to a race condition between uploading resource data to GPU memory and being freed on the host side.

This has been fixed in recent versions of Filament, but other bugs on Windows prevent upgrading.

Only workaround is to load a .glb file.