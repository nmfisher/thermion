---
name: thermion-lighting
description: >
  Light a Thermion scene: direct lights (sun/directional, point, spot) plus
  image-based lighting and backgrounds. Covers DirectLight.sun/.point/.spot
  construction, addDirectLight/removeLight, moving lights, the LightManager
  (color, Kelvin color temperature, intensity units per light type, falloff,
  spot cone angles, sun radius and halo), IBL via loadIbl (intensity, rotation),
  skyboxes (loadSkybox, solid color, background images), and the standard
  IBL+skybox+sun combination. Use when a scene is black, too dark, needs a
  sun/lamp/highlight, or when setting up environment lighting or backgrounds.
  Triggers: light, lighting, sun, directional light, point light, spot light,
  ibl, image based lighting, environment map, skybox, ambient, intensity,
  lux, lumens, candela, color temperature, kelvin, falloff, highlight,
  background color, background image, hdri.
---

Without a light source a Thermion scene renders **black**. There are two light
sources: direct lights (sun/point/spot) and image-based lighting (IBL). The
canonical setup combines an IBL with a skybox from the same environment plus a
sun — that combination is the most flattering default:

```dart
await viewer.loadIbl('assets/default_env_ibl.ktx');
await viewer.loadSkybox('assets/default_env_skybox.ktx');
await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
```

## Direct lights

Build a `DirectLight` with a named constructor, add it with `addDirectLight`,
which returns the light's entity handle:

```dart
// Sun / directional — direction is a normalized vector, NOT a position.
final sunEntity = await viewer.addDirectLight(
  DirectLight.sun(
    direction: Vector3(-0.5, -1, -0.3),
    intensity: 100000,          // lux (default)
    castShadows: true,          // default true for sun
    colorTemperature: 6500,     // Kelvin; alternative to color:
    // color: LinearColor(1.0, 0.9, 0.8),
    sunAngularRadius: 0.545,    // degrees; bigger = softer shadows
  ),
);

// Point — has a world position and falloff.
await viewer.addDirectLight(DirectLight.point(
  position: Vector3(3.5, 2.5, 2.0),
  intensity: 90000,             // lumens
  falloffRadius: 8.0,           // world units; 0 disables falloff
  color: LinearColor(1.0, 0.82, 0.55),
));

// Spot — position + direction + cone.
await viewer.addDirectLight(DirectLight.spot(
  position: Vector3(0, 4, 0),
  direction: Vector3(0, -1, 0),
  intensity: 100000,            // candela
  spotLightConeInner: pi / 8,   // radians
  spotLightConeOuter: pi / 4,   // radians
  falloffRadius: 10.0,
));
```

Removal:

```dart
await viewer.removeLight(lightEntity); // one light
await viewer.destroyLights();          // all direct lights
```

## Moving / mutating lights

Viewer-level (async):

```dart
await viewer.setLightPosition(lightEntity, 1.0, 2.0, 3.0);
await viewer.setLightDirection(lightEntity, Vector3(0, -1, 0));
```

Everything else goes through the light manager. Its setters are
**synchronous** (the exceptions — `setShadowCaster`, `setShadowOptions` — are
async and covered in the shadows skill):

```dart
final lm = viewer.app.lightManager;

lm.setColor(lightEntity, 1.0, 0.9, 0.8);          // linear [0, 1]
lm.setColorTemperature(lightEntity, 6500);         // Kelvin
lm.setIntensity(lightEntity, 120000);              // units per light type
lm.setIntensityCandela(lightEntity, 50000);        // spot: candela explicitly
lm.setIntensityWatts(lightEntity, 60, 0.8);        // watts + efficacy
lm.setFalloff(lightEntity, 8.0);                   // point/spot
lm.setSpotLightCone(lightEntity, pi / 8, pi / 4);  // radians
lm.setSunAngularRadius(lightEntity, 0.545);        // degrees
lm.setSunHaloSize(lightEntity, 10.0);
lm.setSunHaloFalloff(lightEntity, 80.0);

final pos = lm.getPosition(lightEntity);
final dir = lm.getDirection(lightEntity);
```

Intensity units by light type (Filament convention):

| Type | Unit | Default in `DirectLight` |
|---|---|---|
| Sun / directional | lux | 100000 |
| Point | lumens | 100000 |
| Spot | candela | 100000 |

## IBL (image-based lighting)

An IBL is precomputed ambient/reflection lighting, usually generated from an
HDRI with Filament's `cmgen` (produces `_ibl.ktx` + `_skybox.ktx` pairs):

```dart
await viewer.loadIbl('assets/env_ibl.ktx', intensity: 30000); // default 30000
await viewer.loadIblFromTexture(texture, reflectionsTexture: reflections);

await viewer.rotateIbl(Matrix3.rotationY(pi / 4)); // rotate environment
await viewer.removeIbl();                          // destroy: true by default
```

Only **one** IBL is active at a time — `loadIbl` replaces the existing one.

## Skybox & backgrounds

```dart
await viewer.loadSkybox('assets/env_skybox.ktx');  // .ktx cubemap

// Solid color skybox instead:
final skybox = await viewer.setBackgroundColor(0.1, 0.2, 0.4, 1.0);
// ... mutable later:
await skybox.setColor(1.0, 0.0, 0.0, 1.0);

// Background image behind everything (even behind the skybox):
await viewer.setBackgroundImage('assets/bg.png', fillHeight: true);
await viewer.clearBackgroundImage();

final current = await viewer.getSkybox();
final removed = await viewer.removeSkybox(); // detaches; caller destroys it
```

Gotcha: `removeSkybox` detaches but does **not** destroy — you own the returned
`Skybox` (and its texture) after removal.

## Gotchas

- No light → black screen. Either add a sun or load an IBL.
- Sun `direction` points where the light travels (typically downward); it is a
  direction, not a location. Point/spot lights use `position`.
- `color` and `colorTemperature` are alternatives — set one, not both.
- `sunAngularRadius` is in **degrees**; `spotLightConeInner/Outer` are in
  **radians**.
- IBL is replaced (not stacked) by a subsequent `loadIbl`.
- LightManager setters are sync; viewer methods are async — don't `await` the
  manager's `void` setters (it won't compile) and don't skip `await` on viewer
  futures.

## References

- `references/dart-lighting.dart` — complete pure-Dart program: IBL + skybox +
  sun plus a three-point (key/fill/rim) setup of colored point lights.

## Docs

- https://thermion.dev/lighting/ — dedicated lighting page (direct lights,
  light manager, IBL, skybox/backgrounds)
- https://thermion.dev/viewer/ — lighting section of the viewer walkthrough
