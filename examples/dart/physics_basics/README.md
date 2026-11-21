# physics_basics

Standalone Dart example demonstrating rigid-body physics with [`reactphysics3d_dart`](https://github.com/nmfisher/reactphysics3d_dart) and rendering with `thermion_dart` (both headless native and interactive WASM web).

> **Native platform support:** The pinned `reactphysics3d_dart` revision provides prebuilt native libraries for Apple Silicon macOS and x86-64/arm64 Linux. This package is intentionally kept separate from `examples/dart/examples_lib` so the shared examples continue to build on all platforms and the standard web gallery does not need to link ReactPhysics3D.

## Headless (Native)

```sh
cd examples/dart/physics_basics
dart pub get

# Render a 512x512 PNG of the settled pile (5 seconds of simulation) to output/physics_basics.png
dart run bin/physics_basics.dart

# Custom resolution and timestamp (e.g. mid-drop at 1.2s)
dart run bin/physics_basics.dart 800 600 --time 1.2

# Render a 5-second, 30 fps MP4 to output/physics_basics.mp4 (requires ffmpeg)
dart run bin/physics_basics.dart 800 600 --video 5 30
```

## Web (WASM)

The web build links ReactPhysics3D into a dedicated Thermion WASM module. Activate Emscripten 6.0.4 and run from the repository root:

```sh
(cd examples/dart/physics_basics && dart pub get)
make wasm-physics

cp thermion_dart/native/web/build/physics/build/out/thermion_dart.{js,wasm} examples/dart/physics_basics/web/
cp -R examples/assets examples/dart/physics_basics/web/assets

(cd examples/dart/physics_basics && dart compile wasm web/main.dart -o web/main.wasm)
```

Serve `examples/dart/physics_basics/web/` with Cross-Origin Isolation headers (`Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`).
