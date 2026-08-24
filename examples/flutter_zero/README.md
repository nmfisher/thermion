# flutter_zero_basic

Thermion in a **Flutter Zero** app: a plain Dart process with no Flutter
engine, using raw SDL3 (`package:sdl3`) for windowing and input, and
`thermion_dart` (not `thermion_flutter`) for rendering.

Opens an 800×600 window, hands the window's backing native surface to
Filament, and renders a lit cube under an orbiting perspective camera at
60 fps. Escape or closing the window quits.

It is the windowed peer of `examples/dart/cli_headless`, and shows the app
model popularized by the
[`flutter_zero`](https://github.com/nmfisher/flutter_zero) project — this
example depends only on `sdl3` + `thermion_dart`, not on flutter_zero
itself.

## What it demonstrates

1. Booting the Filament backend against an externally-owned native surface
   (`CAMetalLayer` on macOS, X11 `Window` XID on Linux/X11).
2. `FFIFilamentApp.create()` + `createSwapChain()` + `ThermionViewerFFI`
   wired together without any Flutter machinery.
3. Continuous rendering driven by Thermion's port-based `FrameScheduler`
   coexisting with SDL3 event polling on the Dart event loop.
4. A full teardown path (scheduler stop → viewer/swapchain/app destroy →
   SDL shutdown).

## Requirements

- Dart SDK with native assets (3.10+; on by default — no experiment flag).
- A C/C++ toolchain: Thermion compiles its FFI glue locally and links
  against a precompiled Filament archive it downloads at build time.
- **macOS:** `brew install sdl3`
- **Linux:** SDL3 ≥ 3.2 (Ubuntu 24.04's repos still ship SDL2 only — build
  SDL3 from source or use a distro that packages it), plus a Vulkan loader
  (`libvulkan1`) and Mesa's llvmpipe for headless/software rendering.

## Running

```sh
cd examples/flutter_zero
dart pub get
dart run lib/main.dart
```

Headless under Xvfb (Linux):

```sh
xvfb-run -s "-screen 0 800x600x24" dart run lib/main.dart
```

Smoke test that exits by itself after 120 frames (useful for CI):

```sh
xvfb-run -s "-screen 0 800x600x24" dart run lib/main.dart --frames=120
```

Expected output: a window (or Xvfb framebuffer) with a dark background and
a lit cube, and one `frame N` line per second on stdout (`frame 60`,
`frame 120`, …). Escape, closing the window, or `--frames` triggers
`Shutting down...` then `Goodbye!`.

Verified headless on Linux x86_64 (Ubuntu 24.04, Xvfb + llvmpipe software
Vulkan, SDL 3.4.14 built from source, `sdl3` 2.11.0): the app boots,
renders at ~60 fps, and shuts down cleanly.
The macOS/Metal path follows the reference pattern but needs a real
macOS machine to confirm.

## The Flutter Zero model, in brief

- One plain Dart `main()` — no `runApp`, no widgets, no Flutter engine.
- Windowing/input come from a native library (here SDL3) bound via FFI.
- Rendering talks to Thermion's native layer directly
  (`thermion_dart`'s FFI implementation), not through a Flutter plugin.

## Frames are NOT auto-driven — you must schedule them

This is the single most important thing to know when using Thermion
without Flutter. `setRendering(true)` only attaches a view to a swapchain;
it does **not** start a render loop. Something must call
`FilamentApp.instance!.render()` once per frame:

- Under Flutter, Thermion hooks the engine's vsync, so this is easy to miss.
- In a Flutter Zero app *you* own frame pacing. This example uses the
  port-based `FrameScheduler`: `FrameScheduler_startWithPort` spawns a
  native scheduler thread that posts one tick per frame to a Dart
  `ReceivePort` at the requested fps; the listener pumps SDL events,
  updates the camera, and calls `render()`. The same pattern is used by
  `examples/dart/cli_windows`.
- The alternative is a scheduler synced to your UI/compositor pulse if you
  build one — any mechanism that calls `render()` on a steady cadence works.

## Implementation notes

- **macOS Metal layer.** The `sdl3` 2.8–2.11 Dart bindings for
  `SDL_Metal_CreateView` / `SDL_Metal_GetLayer` have broken C signatures
  (they declare `Void` returns and drop the view argument), so `main.dart`
  looks both symbols up with `DynamicLibrary.open(...)` and calls them with
  the correct signatures.
- **Linux X11.** Filament's stock Vulkan platform on Linux interprets the
  swapchain handle as an X11 `Window` XID (see `filament/SwapChain.h`).
  SDL3 exposes it via `SDL_PROP_WINDOW_X11_WINDOW_NUMBER`. Wayland and
  Windows would need their own glue.
- **Build mode.** `pubspec.yaml` sets `hooks.user_defines.thermion_dart.mode:
  release` because Thermion only publishes prebuilt Linux Filament binaries
  in release mode (macOS has both). See the notes in
  `thermion_dart/hook/build.dart`.