---
name: thermion-getting-started
description: >
  Set up and render a first 3D scene with Thermion, on Flutter or pure Dart.
  Covers creating a ThermionViewer (ViewerWidget, ThermionFlutterPlugin.createViewer,
  or headless FFIFilamentApp), loading a glTF model with image-based lighting and
  a skybox, adding a sun light, positioning the camera, enabling post-processing,
  and disposing the viewer. Use when starting a Thermion project, creating a
  viewer, wiring ThermionWidget, or setting up a headless/offscreen renderer.
  Triggers: thermion setup, first scene, create viewer, ThermionViewer,
  ViewerWidget, ThermionWidget, createViewer, FilamentApp, headless viewer,
  hello world 3d, thermion flutter, thermion dart.
---

Teaches the three ways to bring up a Thermion renderer and the canonical
"hello world" scene. Read this before any other Thermion skill — it defines
the setup boilerplate the others assume.

There is **no `ThermionController`** class. The central object is a
`ThermionViewer` (one Scene + Camera + View). Low-level engine access is
`viewer.app`, a `FilamentApp`.

## Flutter — high level (`ViewerWidget`)

One widget does everything: creates a viewer, loads an asset, IBL + skybox,
a light, and orbit controls. Start here unless you need custom scene setup.

```dart
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

ViewerWidget(
  assetPath: 'assets/cube.glb',          // glTF/GLB to load
  skyboxPath: 'assets/default_env_skybox.ktx',
  iblPath: 'assets/default_env_ibl.ktx',
  directLight: DirectLight.sun(direction: Vector3(0, -1, -1)),
  transformToUnitCube: true,             // normalize model scale to a unit cube
  initialCameraPosition: Vector3(0, 0, 6),
  manipulatorType: ManipulatorType.ORBIT, // or FREE_FLIGHT, NONE
  onViewerAvailable: (viewer) async {
    // Optional: grab the ThermionViewer for further scene control.
  },
  onAssetLoaded: (viewer, asset) async {
    // Optional: called once the glTF is in the scene.
  },
)
```

## Flutter — low level (`createViewer` + `ThermionWidget`)

For custom scene setup, create the viewer yourself and render it with
`ThermionWidget`:

```dart
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

ThermionViewer? _viewer;

// e.g. in initState:
_viewer = await ThermionFlutterPlugin.createViewer();
await _viewer!.loadIbl('assets/default_env_ibl.ktx');
await _viewer!.loadSkybox('assets/default_env_skybox.ktx');
final asset = await _viewer!.loadGltf('assets/cube.glb');

// The default camera sits at the origin looking down -Z — inside your model.
// Move it back with lookAt (camera position first, optional focus point):
final camera = await _viewer!.getActiveCamera();
await camera.lookAt(Vector3(0, 1, 10), focus: Vector3(0, 0, 0));

// Without a light source the scene renders black. A sun is the usual choice:
await _viewer!.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));

// Post-processing (tone mapping, anti-aliasing, bloom) is OFF by default.
// If unsure, turn it on:
await _viewer!.setPostProcessing(true);

// In build:
// ThermionWidget(viewer: _viewer!)
```

Declare assets in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/
```

## Pure Dart — headless (no Flutter, no window)

Used for CLI rendering, server-side rendering, and tests. Rendering goes to an
offscreen swapchain you capture to pixels — see the `thermion-headless-capture`
skill for capture details.

```dart
import 'dart:io' as io;
import 'package:thermion_dart/thermion_dart.dart';
// FFIFilamentApp is not exported from the public barrel — import from src,
// exactly as the canonical examples do:
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

await FFIFilamentApp.create(
  config: FFIFilamentConfig(
    loadResource: (uri) async {
      // The default loader chokes on file:// — strip it and read from disk.
      final path = uri.replaceAll('file://', '');
      return io.File(path).readAsBytes();
    },
  ),
);
final app = FilamentApp.instance!;
final swapChain = await app.createHeadlessSwapChain(width, height);

final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
await viewer.initialized;
await app.renderManager.attach(viewer.view, swapChain); // give rendering a target
await viewer.setViewport(width, height);

// ...same scene setup as above: loadIbl / loadSkybox / loadGltf / lookAt...
```

In pure Dart, load assets with **`file://` URIs** (`file:///abs/path/cube.glb`).
In Flutter, plain paths are asset-bundle paths; `file://` selects the filesystem.

## Disposal

```dart
// Flutter teardown, in order:
// 1) remove all ThermionWidget/ViewerWidget instances from the widget tree
// 2) drop all references to the ThermionViewer
// 3) await viewer.dispose();
await viewer.dispose();
```

## Gotchas

- **Only one viewer can be active at a time** (native). Creating a new viewer
  before `dispose()` on the old one throws. (Web is per-viewer.)
- **The default camera is at `(0, 0, 0)` looking down `-Z`** — a model loaded at
  the origin starts inside the camera. Always `lookAt` from a distance.
- Coordinates are right-handed, **+Y up, −Z into the screen**.
- Without a light (sun or IBL) everything renders black.
- `setPostProcessing(true)` is off by default — enable it for tone mapping and
  anti-aliasing unless you specifically need it off.
- The first native build downloads prebuilt Filament binaries (cached after);
  `flutter clean` triggers a fresh download.
- Nearly every Thermion API is asynchronous — `await` every call.

## References

- `references/flutter-viewerwidget.dart` — minimal complete Flutter app using
  the high-level widget.
- `references/dart-headless-minimal.dart` — minimal pure-Dart program that sets
  up a headless renderer and captures one frame to PNG.

## Docs

- https://thermion.dev/quickstart/ — ViewerWidget walkthrough
- https://thermion.dev/viewer/ — ThermionViewer in Flutter
- https://thermion.dev/filament-api/ — dropping down to FilamentApp
