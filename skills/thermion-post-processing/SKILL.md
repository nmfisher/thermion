---
name: thermion-post-processing
description: >
  Enable and configure post-processing in Thermion: the post-processing toggle,
  anti-aliasing (MSAA, FXAA, TAA), bloom, color grading with tone mappers
  (ACES, filmic, AgX, pbrNeutral) plus exposure/white balance/contrast/
  saturation/vibrance, fog, and ambient occlusion (SAO/GTAO). Use for tone
  mapping, glow, jagged edges, washed-out or flat colors, color correction,
  atmosphere/fog, or contact darkening in crevices. Triggers: post processing,
  postprocessing, anti aliasing, antialiasing, fxaa, msaa, taa, jagged edges,
  bloom, glow, tone mapping, tone mapper, aces, agx, filmic, color grading,
  color correction, exposure, white balance, contrast, saturation, vibrance,
  lut, fog, haze, ambient occlusion, sao, gtao.
---

Post-processing is **off by default**. Without it there is no tone mapping,
no anti-aliasing, and HDR scenes look wrong. If unsure, turn it on:

```dart
await viewer.setPostProcessing(true);
```

## Anti-aliasing

```dart
await viewer.setAntiAliasing(msaa, fxaa, taa);
// e.g. FXAA only — the common lightweight choice:
await viewer.setAntiAliasing(false, true, false);
```

## Bloom

```dart
await viewer.setBloom(true, 0.5); // enabled, strength
```

## Color grading & tone mapping

Grading is caller-owned: build with a builder chain, dispose the builder (and
tone mapper) after `build()`, and keep the grading attached for the view's
lifetime — or `setColorGrading(null)` + dispose when replacing it.

```dart
// Tone-mapped grading (ACES):
final builder = await viewer.view.createColorGradingBuilder();
final toneMapper = await ToneMapper.aces(viewer.app);
final grading = await builder
    .toneMapper(toneMapper)
    .quality(QualityLevel.HIGH)
    .exposure(1.2)
    .whiteBalance(0.3, 0.05) // temperature shift, tint
    .contrast(1.1)
    .saturation(1.1)
    .vibrance(1.2)
    .build();
await builder.dispose();
await toneMapper.dispose(); // grading holds a copy
await viewer.view.setColorGrading(grading);
```

Available tone mappers: `ToneMapper.aces`, `.acesLegacy`, `.filmic`,
`.pbrNeutral`, `.agx(app, look:)`, `.generic(...)`, `.displayRange`. If you
skip `toneMapper(...)`, the builder defaults to ACES (legacy).

Builder also supports `.nightAdaptation()`, `.channelMixer()`,
`.shadowsMidtonesHighlights()`, `.slopeOffsetPower()`, `.curves()`,
`.luminanceScaling()`, `.gamutMapping()`, `.dimensions()`/`.format()` for LUT
configuration.

## Fog

```dart
await viewer.view.setFogOptions(FogOptions(
  enabled: true,
  density: 0.1,
  distance: 0.0,
  cutOffDistance: double.infinity,
  maximumOpacity: 1.0,
  linearColor: Vector3(0.8, 0.85, 0.9),
  height: 0.0,
  heightFalloff: 1.0,
  fogColorFromIbl: false, // tint fog from the skybox instead of linearColor
));
```

## Ambient occlusion

```dart
await viewer.view.setAmbientOcclusionOptions(
  AmbientOcclusionOptions(enabled: true, radius: 0.3, intensity: 1.0),
);
```

(SAO/GTAO variants and full field list live on `AmbientOcclusionOptions` /
`View.setAmbientOcclusionOptions`.)

## Gotchas

- `setPostProcessing(true)` gates everything else — no point tuning bloom or
  grading while it's off.
- Builder and tone mapper are **disposable**: dispose both after `build()`;
  the built `ColorGrading` is yours to detach (`setColorGrading(null)`) and
  dispose when replacing.
- `setAntiAliasing` is a three-flag tuple `(msaa, fxaa, taa)`.
- Grading quality: use `QualityLevel.HIGH` for stills, lower for mobile.
- Fog with `fogColorFromIbl: true` ignores `linearColor`.

## References

- `references/dart-post-processing.dart` — complete pure-Dart program with
  FXAA, bloom, ACES tone-mapped warm grading, and fog.

## Docs

- https://thermion.dev/materials/ and the bundled reference; Filament's docs
  cover the underlying model: https://google.github.io/filament/Filament.html
