---
name: thermion-shadows
description: >
  Enable and configure shadows in Thermion. Covers the three switches that all
  must be on (view-level setShadowsEnabled, a shadow-casting light, and a
  shadow-receiving surface), shadow types (PCF, VSM, DPCF, PCSS), per-light
  castShadows and ShadowOptions via the LightManager (map size, cascades and
  split positions, biases, screen-space contact shadows), per-renderable
  setCastShadows/setReceiveShadows, soft-shadow tuning, and ground-plane
  shadows. Use when objects should cast or receive shadows, shadows look wrong
  (acne, peter-panning, pixelated), or for cascaded shadow setup.
  Triggers: shadow, shadows, cast shadow, receive shadow, shadow map, shadow
  type, pcf, vsm, dpcf, pcss, soft shadows, shadow cascade, split positions,
  shadow bias, shadow acne, contact shadows, ground shadow, drop shadow.
---

Shadows in Thermion need **three things switched on** — miss any one and you
get no shadows:

1. Shadows enabled on the view,
2. a light that **casts** shadows,
3. a surface that **receives** shadows.

The minimal working setup (a floating cube over a ground plane):

```dart
// A ground plane to receive shadows (there is no dedicated ground-shadow API —
// you add receiving geometry):
final ground = await viewer.createGeometry(GeometryUtils.plane(width: 10, height: 10));
await ground.setReceiveShadows(true);

final cube = await viewer.loadGltf('assets/cube.glb');
await cube.setTransform(Matrix4.translation(Vector3(0, 0.5, 0)));

// A shadow-casting sun:
await viewer.addDirectLight(
  DirectLight.sun(castShadows: true, direction: Vector3(-1, -2, -1)),
);

// View-level switches:
await viewer.setShadowsEnabled(true);
await viewer.setShadowType(ShadowType.PCF);
```

## The three switches live at different levels

| Level | API | Default |
|---|---|---|
| View | `viewer.setShadowsEnabled(bool)` / `viewer.setShadowType(...)` | disabled |
| Light | `DirectLight(castShadows:)` or `lightManager.setShadowCaster(entity, true)` | `false` (sun constructor: `true`) |
| Renderable | `asset.setCastShadows(bool)` / `asset.setReceiveShadows(bool)` | cast: on, receive: on for geometry |

## Shadow types

```dart
await viewer.setShadowType(ShadowType.PCF);  // percentage-closer filtering — default choice
await viewer.setShadowType(ShadowType.VSM);  // variance shadow maps — softer, may leak light
await viewer.setShadowType(ShadowType.DPCF); // soft, cheaper than PCSS
await viewer.setShadowType(ShadowType.PCSS); // physically-based soft shadows
```

(Equivalently `viewer.view.setShadowType(...)`.)

Tuning soft shadows (DPCF/PCSS):

```dart
await viewer.view.setSoftShadowOptions(
  SoftShadowOptions(penumbraScale: 0.5, penumbraRatioScale: 0.5),
);
```

## Per-light ShadowOptions

Via the light manager (`setShadowOptions` is one of its few **async** methods),
using the entity returned by `addDirectLight`:

```dart
final sunEntity = await viewer.addDirectLight(
    DirectLight.sun(castShadows: true, direction: Vector3(0, -1, -1)));

await viewer.app.lightManager.setShadowOptions(
  sunEntity,
  ShadowOptions(
    mapSize: 1024,              // shadow map resolution
    shadowCascades: 4,          // directional lights only
    cascadeSplitPositions: [0.125, 0.25, 0.50], // N-1 splits for N cascades
    constantBias: 0.001,
    normalBias: 0.01,
    shadowFar: 100.0,
    screenSpaceContactShadows: true, // per-light contact shadows
  ),
);
```

Cascade split helpers (fractions of the shadow distance):

```dart
final lm = viewer.app.lightManager;
final uniform = lm.computeUniformSplits(4);
final log = lm.computeLogSplits(4, near, far);
final practical = lm.computePracticalSplits(4, near, far, 0.5); // lambda blend
```

VSM-specific view options:

```dart
await viewer.view.setVsmShadowOptions(VsmShadowOptions(msaaSamples: 4));
```

## Moving shadows

Shadow direction follows the light: move the sun and the shadows follow.

```dart
await viewer.setLightDirection(sunEntity, Vector3(-0.5, -1, -0.2));
```

Softer shadow edges: increase the sun's angular radius.

```dart
viewer.app.lightManager.setSunAngularRadius(sunEntity, 2.0); // degrees
```

## Gotchas

- **No dedicated ground-shadow API** — "a shadow on the floor" means a plane
  (or any geometry) with `setReceiveShadows(true)`.
- `setShadowsEnabled(true)` alone is not enough — the light must cast and a
  surface must receive.
- Shadow **acne** (striping): raise `constantBias`/`normalBias` or `mapSize`.
  **Peter-panning** (detached shadows): biases too high — lower them.
- Pixelated shadow edges: higher `mapSize`, more cascades, or switch
  PCF → DPCF/PCSS.
- Cascade count vs splits: N cascades take exactly N−1 split positions.
- Directional/sun lights support cascades; point/spot lights do not.

## References

- `references/dart-shadows.dart` — complete pure-Dart program: cube over a
  ground plane with PCF shadows from a shadow-casting sun, plus ShadowOptions
  tuning.

## Docs

- https://thermion.dev/shadows/ — dedicated shadows page (the three switches,
  shadow types, per-light options, troubleshooting)
- Filament's own shadow docs describe the underlying model:
  https://google.github.io/filament/Filament.html#shadowing
