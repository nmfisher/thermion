---
name: thermion-picking-selection
description: >
  Detect which 3D object a user clicked or tapped in Thermion, and show visual
  selection. Covers View.pick ray casting with PickResult (entity, depth),
  screen-to-viewport coordinate mapping, stencil highlight outlines
  (setStencilHighlight with outlineWidth, highlight overlay setup, the
  rebuildVertices requirement), and translation gizmos. Use for click/tap
  detection on 3d objects, selecting meshes, selection outlines, highlighting,
  or dragging objects with a gizmo. Triggers: pick, picking, raycast, ray
  cast, click detection, tap, hit test, hit test, which object was clicked,
  select, selection, highlight, outline, silhouette, stencil, gizmo, drag
  object, transform gizmo.
---

Picking answers "what did the pointer hit?" — `View.pick` ray-casts from the
camera through a screen point and reports the entity and depth.

## Picking

```dart
// x, y are integer logical (viewport) coordinates, origin at the TOP-LEFT.
await viewer.view.pick(x, y, (PickResult result) {
  if (result.entity != 0) {
    print('Hit entity ${result.entity} at depth ${result.depth}');
    // Map back to an asset: compare against asset.entity / child entities /
    // instance entities you tracked when loading.
  }
});
```

`PickResult` is a record: `entity`, `x`, `y`, `depth`, `fragX`, `fragY`,
`fragZ`. An entity of 0 means no hit.

In Flutter, pointer coordinates are widget-local logical coordinates, top-left
origin — they already match the viewport (round to `int`, which `pick` takes):

```dart
GestureDetector(
  onTapUp: (details) async {
    final pos = details.localPosition;
    await viewer.view.pick(pos.dx.round(), pos.dy.round(), (result) { ... });
  },
  child: ThermionWidget(viewer: viewer),
)
```

To map a hit back to a loaded asset, keep the handles you got at load time
(`asset.entity`, `asset.getChildEntities()`, instance entities) and compare —
or tag entities on a visibility layer for coarse filtering.

## Selection outline (stencil highlight)

A screen-space outline around a selected asset:

```dart
// 1) Load with rebuilt vertices (REQUIRED — barycentric-aware buffers):
final asset = await viewer.loadGltf('assets/scene.gltf', rebuildVertices: true);

// 2) Enable the overlay + stencil buffer once:
await viewer.view.setHighlightOverlayEnabled(true);
await viewer.view.setStencilBufferEnabled(true);

// 3) Highlight / clear:
await viewer.view.setStencilHighlight(
  asset,
  r: 0.0, g: 1.0, b: 0.0,
  outlineWidth: 3.0,  // pixels; constant regardless of camera distance
);
await viewer.view.removeStencilHighlight(asset);
```

`setStencilHighlight` can target a single entity (`entity:` param) and
primitive (`primitiveIndex:`). It **throws** if the asset wasn't loaded with
`rebuildVertices: true`.

## Gizmos (drag manipulators)

```dart
final gizmo = await viewer.getGizmo(GizmoType.translation);
// also: GizmoType.rotation
// gizmo.pick(x, y, handler:) reports axis drags (returns the axis + coords)
```

Only one gizmo can be visible per viewer. Combine with picking: pick to
select, then attach the gizmo for dragging.

## Gotchas

- Pick coordinates are **top-left origin, logical pixels** — the same as
  Flutter's `localPosition`; don't flip Y yourself.
- Stencil highlights require `loadGltf(..., rebuildVertices: true)` (~3x
  vertex memory) — the call throws otherwise.
- Enable the highlight overlay **before** the first `setStencilHighlight`.
- An entity handle of `0` in `PickResult` = no hit.
- Pick works on what's rendered — hidden layers aren't pickable.

## References

- `references/flutter-picking.dart` — complete Flutter app: three instanced
  cubes, tap to pick, green outline on the tapped instance.

## Docs

- No dedicated picking page on thermion.dev yet — the bundled reference and
  `examples/flutter/picking` in the thermion repository are canonical.
