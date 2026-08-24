---
name: thermion-headless-capture
description: >
  Render Thermion scenes to images without a display, in pure Dart (no
  Flutter). Covers FFIFilamentApp.create with a custom loadResource, the
  headless swapchain, creating and attaching a viewer, viewport sizing,
  capturing frames with FilamentApp.capture (RGBA float or byte pixels), and
  converting to PNG with pixelBufferToPng. Use for CLI renderers, server-side
  rendering, test golden images, screenshots, batch frame rendering, or video
  frame export. Triggers: headless, offscreen, off-screen, render to image,
  screenshot, capture, png, pixel buffer, server side rendering, batch
  render, no window, cli, pure dart, desktop, test images, golden files.
---

Thermion renders without any window: create the engine, attach a viewer to a
headless swapchain, and capture pixels. This is pure Dart — the
`thermion_flutter` package is not involved.

## The full setup

```dart
import 'dart:io' as io;
import 'package:thermion_dart/thermion_dart.dart';
// FFIFilamentApp is not exported from the public barrel — import from src:
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

// 1) Engine with a resource loader that understands file:// URIs.
await FFIFilamentApp.create(
  config: FFIFilamentConfig(
    loadResource: (uri) async {
      final path = uri.replaceAll('file://', '');
      return io.File(path).readAsBytes();
    },
  ),
);
final app = FilamentApp.instance!;

// 2) Offscreen target sized to your desired output resolution.
final swapChain = await app.createHeadlessSwapChain(width, height);

// 3) Viewer attached to that target.
final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
await viewer.initialized;
await app.renderManager.attach(viewer.view, swapChain);
await viewer.setViewport(width, height);

// 4) Normal scene setup: loadIbl / loadGltf / lookAt / addDirectLight...

// 5) Capture.
final result = await app.capture(
  swapChain,
  view: viewer.view,
  pixelDataFormat: PixelDataFormat.RGBA,
  pixelDataType: PixelDataType.FLOAT, // or UBYTE for 8-bit output
);
final pixels = result.first.$2; // Uint8List of packed pixels
```

`capture` returns one `(View, pixels)` pair per captured view — hence
`.first.$2`.

## Pixels → PNG

```dart
final png = await pixelBufferToPng(
  pixels, width, height,
  hasAlpha: true,  // RGBA vs RGB
  isFloat: true,   // must match pixelDataType (FLOAT vs UBYTE)
);
await io.File('frame.png').writeAsBytes(png);
```

## Render loops (animation, camera motion)

Advance animations with the accumulated-clock `animationManager.update`
pattern (see the `thermion-animation` skill), move the camera with `lookAt`,
and capture per frame:

```dart
for (var i = 0; i < frameCount; i++) {
  clockNanos += dtNanos;
  await app.animationManager.update(clockNanos);
  await camera.lookAt(nextOrbitPosition(i), focus: focus);
  // capture + write PNG (as above)
}
```

Cap the engine's frame rate for continuous (non-capture) rendering (sync):

```dart
app.setTargetFramerate(60);
```

## Teardown

```dart
io.exit(0); // after flushing output
```

Gotcha: on exit, Filament's teardown can race gltfio material-instance
destruction and panic ("N instances still alive"). It's harmless once your
output is flushed, so canonical examples skip teardown with a hard exit.

## Gotchas

- **Desktop platforms only** — headless rendering needs a native Filament
  backend (OpenGL/Metal/Vulkan); there is no browser headless path.
- The default resource loader does raw `File` reads and chokes on `file://` —
  always pass a `loadResource` that strips the scheme.
- `isFloat` in `pixelBufferToPng` must match the `pixelDataType` used in
  `capture`.
- Assets are addressed with `file://` URIs (no Flutter asset bundle here).
- Call `viewer.setViewport(width, height)` so aspect ratios match the output.
- For scenes that pop at frame edges during camera motion, disable frustum
  culling: `await viewer.view.setFrustumCullingEnabled(false)`.

## References

- `references/dart-headless-capture.dart` — minimal program capturing one
  frame in both HDR float and 8-bit formats.
- The `thermion-getting-started` skill's `references/dart-headless-minimal.dart`
  is the smallest end-to-end example.

## Docs

- https://thermion.dev/filament-api/ — headless rendering with FilamentApp
