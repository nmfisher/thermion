---
name: thermion-loading-gltf
description: >
  Load, inspect, instance, and clean up glTF/GLB models in Thermion. Covers
  loadGltf and loadGltfFromBuffer parameters (addToScene, initialInstances,
  releaseSourceData, rebuildVertices, resourceUri), the ThermionAsset API
  (entity, child-entity queries, bounding boxes, transformToUnitCube,
  createInstance/getInstance for GPU instancing), scene add/remove, visibility
  layers, and destroyAsset/destroyAssets. Use when loading 3d models, spawning
  copies or instances, traversing an asset's entities, or freeing assets.
  Triggers: load gltf, load glb, load model, ThermionAsset, instances,
  gpu instancing, child entities, bounding box, unit cube, visibility layer,
  destroy asset, free asset, assimp, obj.
---

Everything in a Thermion scene is an **entity**; a loaded glTF becomes a
`ThermionAsset` whose root `entity` owns a subtree of child entities (meshes,
bones, lights). This skill covers loading that asset, querying it, instancing
it, and destroying it.

## Loading

```dart
final asset = await viewer.loadGltf('assets/scene.glb');
```

Key parameters:

```dart
final asset = await viewer.loadGltf(
  'assets/scene.gltf',
  addToScene: true,          // add renderables to the scene immediately
  initialInstances: 4,       // pre-allocate N GPU instances (>= 1)
  releaseSourceData: false,  // true: no further createInstance calls possible
  rebuildVertices: false,    // true: rebuild vertices with barycentrics/etc,
                             //      enabling free material swapping (wireframe,
                             //      flat shading, stencil highlights). ~3x vertex memory.
  resourceUri: null,         // for .gltf: where relative resources live
                             //      (defaults to the .gltf file's own URI)
);
```

URI schemes: **`file://` always works**; **`asset://`** (and plain paths, which
are treated as asset paths) only inside a Flutter application. `.glb` is
self-contained; `.gltf` resolves its `.bin`/textures relative to its own URI
unless you pass `resourceUri`.

From an in-memory buffer:

```dart
final asset = await viewer.loadGltfFromBuffer(bytes);
```

Non-glTF formats (OBJ, FBX, …) are not built in — load them via the
[`assimp_dart`](https://pub.dev/packages/assimp_dart) package, which converts
to glTF buffers first.

## Querying the asset

```dart
final ThermionEntity root = asset.entity;

final names = await asset.getChildEntityNames();   // e.g. meshes by name
final child = await asset.getChildEntity('Wheel'); // lookup by name (nullable)
final children = await asset.getChildEntities();   // all child entities
final hasIt = await asset.containsChild(someEntity);

final Aabb3 bounds = await asset.getBoundingBox();
await asset.transformToUnitCube();                 // normalize to a 1x1x1 cube at the origin
```

Gotcha: `asset.transformToUnitCube()` reads the root entity's bounds, which can
be bogus when the root has no renderable component. If you know the object-space
box, normalize through the transform manager instead:

```dart
viewer.app.transformManager.transformToUnitCube(
  asset.entity, Aabb3.minMax(Vector3(-1, -1, -1), Vector3(1, 1, 1)),
);
```

## GPU instancing

Efficient copies of the same asset, driven by the GPU:

```dart
final asset = await viewer.loadGltf('assets/rock.glb', initialInstances: 100);
for (var i = 0; i < 100; i++) {
  final instance = await asset.getInstance(i);
  await instance.setTransform(Matrix4.translation(Vector3(i * 2.0, 0, 0)));
}
```

- `initialInstances` at load time is more efficient than creating instances
  later.
- Dynamic creation (only while `releaseSourceData` is false):
  `await asset.createInstance()`, then `asset.getInstanceCount()` /
  `asset.getInstances()`.
- With exactly one instance, the parent asset and its instance are
  interchangeable.

## Scene membership & visibility

```dart
await viewer.removeFromScene(asset); // hide but keep valid
await viewer.addToScene(asset);      // show again

// Layers: put entities on a non-default layer, then toggle that layer.
await asset.setVisibilityLayer(childEntity, VisibilityLayers.LAYER_1);
await viewer.setLayerVisibility(VisibilityLayers.LAYER_1, false);
```

## Cleanup

```dart
await viewer.destroyAsset(asset);  // destroys asset + instances
                                  // (NOT manually created material instances —
                                  // destroy those yourself)
await viewer.destroyAssets();      // destroys all renderable entities incl. cameras
```

After `destroyAssets()`, **every** `ThermionEntity` handle is invalid — discard
all references immediately.

## Gotchas

- Default camera sits at the origin — a model at the origin is inside it.
  `camera.lookAt(Vector3(3, 3, 3))` after loading.
- `releaseSourceData: true` (at load or via `asset.releaseSourceData()`) frees
  the CPU-side glTF copy but permanently disables `createInstance`.
- `rebuildVertices: true` is required for later wireframe/flat-shading swaps and
  stencil highlights (`setFlatShading`/`setStencilHighlight` throw without it);
  it costs ~3x vertex memory but preserves animations, skeletons, and
  instancing.

## References

- `references/dart-instancing.dart` — complete pure-Dart program loading one
  cube as four GPU instances.
- `references/flutter-load-destroy.dart` — Flutter load/unload lifecycle with
  correct teardown order.

## Docs

- https://thermion.dev/entities/ — loading, entity queries, instancing, cleanup
- https://thermion.dev/viewer/ — loading section of the viewer walkthrough
