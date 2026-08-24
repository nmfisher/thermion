---
name: thermion-camera-input
description: >
  Position and control the camera, and add user interaction, in a Thermion
  scene. Covers camera lookAt (there is no setCameraPosition), lens
  projection (focal length) and field-of-view projections, exposure, multiple
  cameras, orbit and free-flight controls via ManipulatorType on ViewerWidget
  or DelegateInputHandler with ThermionListenerWidget, sensitivity tuning, and
  writing custom input handlers. Use when framing a shot, moving the camera,
  adding drag/scroll/zoom controls, or handling touch and mouse input.
  Triggers: camera, lookAt, camera position, move camera, orbit, orbit
  controls, free flight, first person, field of view, fov, projection, focal
  length, zoom, exposure, aperture, input handler, mouse, touch, scroll wheel,
  sensitivity, manipulator, drag rotate.
---

There is **no `setCameraPosition`** on the viewer. Get the active camera and
aim it with `lookAt` — first argument is the camera's position, then an
optional focus point (defaults to the origin) and up vector (defaults to +Y):

```dart
final camera = await viewer.getActiveCamera();
await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));
final Vector3 pos = camera.getPosition();
```

The default camera sits at `(0, 0, 0)` looking down −Z — inside any object
placed at the origin. Always `lookAt` from a distance after loading.

## Projection

```dart
// Physical lens (default feel): focal length in mm.
await camera.setLensProjection(near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);

// Or an explicit field of view:
await camera.setProjectionFromVerticalFieldOfView(45.0, 0.1, 1000.0, aspect);
await camera.setProjectionFromHorizontalFieldOfView(60.0, 0.1, 1000.0, aspect);

// Exposure (aperture f-number, shutter speed seconds, sensitivity ISO):
await camera.setExposure(16.0, 1 / 125, 100.0);
```

After `viewer.setViewport(w, h)` cameras update to the new aspect ratio.

## Multiple cameras

```dart
final cam2 = await viewer.createCamera();
await cam2.lookAt(Vector3(0, 10, 0), focus: Vector3(0, 0, 0));
await viewer.setActiveCamera(cam2);       // render from cam2
await viewer.destroyCamera(cam2);          // cleanup
final count = viewer.getCameraCount();
```

## Flutter — built-in controls (ViewerWidget)

```dart
ViewerWidget(
  assetPath: 'assets/cube.glb',
  initialCameraPosition: Vector3(0, 2, 4),
  manipulatorType: ManipulatorType.ORBIT, // ORBIT | FREE_FLIGHT | NONE
);
```

## Flutter — manual controls (ThermionListenerWidget)

Wrap `ThermionWidget` in a `ThermionListenerWidget` with a delegate input
handler — this is the low-level path when you create the viewer yourself:

```dart
ThermionListenerWidget(
  inputHandler: DelegateInputHandler.fixedOrbit(
    viewer,
    minimumDistance: 0.1,     // how close the camera may zoom
    sensitivity: InputSensitivityOptions(
      scrollWheelSensitivity: 0.005,
    ),
  ),
  child: ThermionWidget(viewer: viewer),
);

// Free-flight (WASD-style) instead of orbit:
DelegateInputHandler.flight(viewer, freeLook: true)
```

`fixedOrbit` options: `target` (orbit center), `minimumDistance`,
`moveOnHover`, `sensitivity`. `flight` options: `freeLook`, `moveOnHover`,
`sensitivity`. Sensitivity covers touch, mouse, scroll, and keys via
`InputSensitivityOptions`.

## Custom input handling

Implement an input handler delegate to route arbitrary Flutter gestures into
camera motion (or picking — see the `thermion-picking-selection` skill):

```dart
GestureDetector(
  onPanUpdate: (details) {
    // Convert deltas to orbit angles and call camera.lookAt yourself.
  },
  child: ThermionWidget(viewer: viewer),
)
```

## Gotchas

- Camera motion is `lookAt` / `setModelMatrix` / `setTransform(Matrix4)` — not
  `setPosition`.
- `lookAt` positions the camera at the FIRST argument; the focus is what it
  looks AT. Swapping them is the classic mistake.
- +Y is up, −Z is into the screen (right-handed).
- FOV functions take **degrees**; `setLensProjection` takes millimeters.
- `ViewerWidget` installs its own manipulator; don't add a
  `ThermionListenerWidget` around it.

## References

- `references/dart-camera-projections.dart` — complete pure-Dart program
  comparing lens and FOV projections.

## Docs

- https://thermion.dev/camera-manipulation/ — orbit/free-flight/custom input
