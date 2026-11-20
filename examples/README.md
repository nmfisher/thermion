# Thermion Examples

This repository contains example Dart and Flutter projects for the Thermion rendering toolkit.

## Dart examples

Shared scene setups live in `dart/examples_lib`; each is registered in
`dart/examples_lib/lib/src/registry.dart`. Render any of them offscreen with
the headless CLI runner:

```sh
cd dart/headless_runner
dart run bin/run_example.dart <name> [width] [height]   # PNG lands in output/
```

Run `physics_basics` in the headless runner or open `?example=physics` in the
web gallery. The pinned physics dependency provides native libraries for Apple
Silicon macOS and for x86-64 and arm64 Linux. The gallery build links ReactPhysics3D into a dedicated Thermion
Wasm engine. To build that engine locally, activate Emscripten 6.0.4 and run:

```sh
(cd examples/dart/web_gallery && dart pub get)
make wasm-physics
cp thermion_dart/native/web/build/physics/build/out/thermion_dart.{js,wasm} examples/dart/web_gallery/web/
```

The build uses the same ReactPhysics3D source revision resolved by the Dart
gallery. See the gallery’s existing instructions for compiling and serving it.

## flutter_zero

[`flutter_zero/`](flutter_zero/) — a "Flutter Zero" app: a plain Dart process with no Flutter engine, using raw SDL3 for windowing/input and `thermion_dart` directly for rendering. Demonstrates native-surface acquisition (CAMetalLayer on macOS, X11 on Linux) and port-based `FrameScheduler` frame pacing. See [flutter_zero/README.md](flutter_zero/README.md).
