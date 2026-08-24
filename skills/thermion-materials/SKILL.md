---
name: thermion-materials
description: >
  Control surface appearance in Thermion: create and configure materials.
  Covers the PBR ubershader (base color, metallic, roughness, emissive,
  textures), unlit and wireframe built-in material instances, generic
  parameter setters (setParameterFloat/Float3/Float4/Int/Bool/Texture/Mat3/Mat4),
  texture binding with samplers, swapping materials on loaded assets
  (setMaterialInstanceForAll, setMaterialInstanceAt), flat vs smooth shading,
  and the rebuildVertices requirement. Use when changing an object's color,
  making it metallic/rough/glowing, showing wireframe, applying textures, or
  swapping materials at runtime. Triggers: material, materials, pbr, metallic,
  roughness, base color, color, texture, unlit, wireframe, flat shading,
  material instance, setParameter, transparency, emissive, appearance, shader.
---

A material instance controls how a surface is shaded. Thermion ships three
built-in materials — the PBR **ubershader**, **unlit**, and **wireframe** —
created from the app (`viewer.app`, or `FilamentApp.instance!` in
single-viewer apps) and applied to assets or geometry.

## PBR ubershader

```dart
final mat = await viewer.app.createUbershaderMaterial();

// Factors:
await mat.setBaseColorFactor(0.85, 0.5, 0.2, 1.0); // linear RGBA
await mat.setMetallicFactor(1.0);   // 0 = dielectric, 1 = metal
await mat.setRoughnessFactor(0.15); // 0 = mirror, 1 = fully diffuse
await mat.setEmissiveFactor(1.0, 0.0, 0.0, 1.0);
await mat.setDoubleSided(true);

// Textures (see below for creating them):
await mat.setBaseColorTexture(texture, sampler);

// Apply to everything in the asset:
await asset.setMaterialInstanceForAll(mat.materialInstance);
```

Note the `.materialInstance` getter — the typed wrapper wraps a plain
`MaterialInstance`, and the asset APIs take the plain one. The two factories
differ in what they return: `createUbershaderMaterial()` gives you the typed
wrapper with named PBR setters; `createUbershaderMaterialInstance(...)` gives
you a plain `MaterialInstance` (configure it with `setParameter*`, e.g.
`setParameterFloat4('baseColorFactor', ...)`).

PBR really shows under image-based lighting — load an IBL alongside (see the
`thermion-lighting` skill).

Limitation: Filament's ubershader does **not** support
transmission/volume/sheen/IOR together with clearcoat — pick either the
clearcoat family or the transmission family of features, not both.

## Unlit and wireframe

```dart
// Unlit: flat color, ignores all lighting.
final unlit = await viewer.app.createUnlitMaterialInstance();

// Wireframe: edges + faces with separate colors (requires the asset to have
// been loaded with rebuildVertices: true — see Gotchas).
final wireframe = await viewer.app.createWireframeMaterialInstance();
await wireframe.setEdgeColor(0.3, 0.3, 0.3, 1.0);
await wireframe.setFaceColor(0.1, 0.1, 0.1, 1.0);
await wireframe.setEdgeWidth(0.5);
await asset.setMaterialInstanceForAll(wireframe.materialInstance);
```

`setEdgeWidth` is in pixels.

## Swapping materials on an asset

```dart
// Whole asset:
await asset.setMaterialInstanceForAll(newInstance);

// One primitive of one entity (index-based):
await asset.setMaterialInstanceAt(newInstance, entity: meshEntity, primitiveIndex: 0);
final current = await asset.getMaterialInstanceAt(entity: meshEntity, index: 0);

// Snapshot/restore all instances at once:
final saved = await asset.getMaterialInstancesAsMap();
await asset.setMaterialInstancesFromMap(saved);
```

Loading with `rebuildVertices: true` makes these swaps work on any glTF
(the loader rebuilds vertex buffers with a superset of attributes).

## Generic parameter setters

Any `MaterialInstance` (including ones inside loaded glTFs) exposes typed
setters keyed by the material's parameter names:

```dart
final instance = await asset.getMaterialInstanceAt(index: 0);

await instance.setParameterFloat('metallic', 0.8);
await instance.setParameterFloat4('baseColorFactor', 1.0, 0.0, 0.0, 1.0);
await instance.setParameterFloat3('emissiveFactor', 0.0, 1.0, 0.0);
await instance.setParameterInt('mode', 2);
await instance.setParameterBool('flipUVs', true);
await instance.setParameterTexture('baseColorMap', texture, sampler);
await instance.setParameterMat4('transform', matrix4);
```

Parameter names come from the material definition — for glTF-embedded
materials, check the glTF's `extra`/extension data or the source `.mat` for
what a given material supports.

## Textures

```dart
// Decode encoded bytes (PNG/JPEG) into a caller-owned LinearImage:
final image = await viewer.app.decodeImage(pngBytes);
// ...then upload into a texture sized to the image:
final texture = await viewer.app.createTexture(width, height);

final sampler = await viewer.app.createTextureSampler(
  minFilter: TextureMinFilter.LINEAR,
  magFilter: TextureMagFilter.LINEAR,
);

await mat.setBaseColorTexture(texture, sampler);
```

Dispose textures, samplers, and decoded `LinearImage`s (`image.destroy()`)
when done — GPU memory is not garbage-collected.

## Flat vs smooth shading

```dart
final asset = await viewer.loadGltf('assets/rock.glb', rebuildVertices: true);
await asset.setFlatShading(true);   // per-face normals
await asset.setFlatShading(false);  // per-vertex (smooth)
```

Throws unless the asset was loaded with `rebuildVertices: true` (flat
shading swaps TANGENTS on the rebuilt vertex buffers).

## Gotchas

- `setFlatShading` and `setStencilHighlight` **throw** unless the asset was
  loaded with `loadGltf(..., rebuildVertices: true)` (~3x vertex memory);
  wireframe swaps also need it.
- Color values are **linear** (not sRGB) floats in `[0, 1]`.
- Unlit materials ignore lights and IBL entirely.
- The ubershader's clearcoat can't coexist with transmission/sheen/IOR.
- Typed wrappers (`UbershaderMaterialInstance`, `WireframeMaterialInstance`)
  expose `.materialInstance` — the asset APIs want the inner instance.

## References

- `references/dart-materials.dart` — complete pure-Dart program: PBR metallic
  cube plus a wireframe cube side by side.

## Docs

- https://thermion.dev/materials/ — materials, textures, and procedural
  geometry walkthrough
