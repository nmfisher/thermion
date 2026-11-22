# physics_basics

Standalone Dart example demonstrating rigid-body physics with [`reactphysics3d_dart`](https://pub.dev/packages/reactphysics3d_dart) and rendering with `thermion_dart` (both headless native and interactive WASM web).

> This package is intentionally kept separate from `examples/dart/examples_lib` and `examples/dart/web_gallery` so the standard web gallery does not need to link ReactPhysics3D into the main Thermion WASM bundle.

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

No Emscripten build is required — both `thermion_dart` and `reactphysics3d_dart` ship prebuilt WASM modules:

```sh
cd examples/dart/physics_basics
dart pub get

# 1. Download Thermion's prebuilt WASM module into web/
dart run thermion_dart:download_web --output=web

# 2. Copy ReactPhysics3D's prebuilt WASM module from the resolved pub package into web/
RP3D_DIR=$(python3 -c 'import json; from pathlib import Path; from urllib.parse import unquote, urljoin, urlsplit; c = Path(".dart_tool/package_config.json").resolve(); print(next(unquote(urlsplit(urljoin(c.as_uri(), p["rootUri"])).path) for p in json.loads(c.read_text())["packages"] if p["name"] == "reactphysics3d_dart"))')
cp "$RP3D_DIR"/native/web/reactphysics3d_dart.{js,wasm} web/

# 3. Copy shared skybox/IBL assets and compile the Dart WASM app
cp -R ../../assets web/assets
dart compile wasm web/main.dart -o web/main.wasm
```

Serve `examples/dart/physics_basics/web/` with Cross-Origin Isolation headers (`Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`).
