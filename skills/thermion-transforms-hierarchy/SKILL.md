---
name: thermion-transforms-hierarchy
description: >
  Position, rotate, scale, and move 3D objects in Thermion. Thermion has NO
  setPosition/setRotation/setScale helpers — every transform is a Matrix4 from
  vector_math_64. Covers asset.setTransform, Matrix4.compose with Quaternion,
  common transform recipes (translation, rotationY spin, orbiting), the
  TransformManager (local vs world transforms, setTransformAsync, transform
  transactions), and scene-graph parenting via setParent. Use when moving,
  placing, rotating, scaling, or animating object positions, or building
  parent/child hierarchies. Triggers: set position, move object, translate,
  rotate, scale, spin, matrix4, quaternion, transform manager, parent entity,
  child entity, scene graph, hierarchy, world transform, local transform,
  pivot, orbit object.
---

**There is no `setPosition`, `setRotation`, or `setScale` in Thermion.** Every
placement is a `Matrix4` (from `package:vector_math/vector_math_64.dart`)
applied with `setTransform`. If you find yourself looking for those helpers,
compose a matrix instead.

## The everyday pattern

```dart
import 'package:vector_math/vector_math_64.dart';

// Pure translation:
await asset.setTransform(Matrix4.translation(Vector3(0, 1, 2)));

// Compose position + rotation + scale in one matrix:
final transform = Matrix4.compose(
  Vector3(0, 1, 2),                      // position
  Quaternion.fromEulerAngles(0, pi / 4, 0), // rotation
  Vector3(1, 1, 1),                      // scale
);
await asset.setTransform(transform);

// Set a child entity's transform instead of the asset root:
await asset.setTransform(Matrix4.translation(Vector3(1, 0, 0)),
    entity: childEntity);
```

`setTransform` **replaces** the whole transform — it does not accumulate. To
move relative to the current pose, read, modify, write:

```dart
final current = await asset.getLocalTransform();
current.translate(Vector3(0, 0.5, 0)); // mutate in place
await asset.setTransform(current);
```

## Common recipes

```dart
// Continuous spin (e.g. from a Timer.periodic or ticker):
await asset.setTransform(Matrix4.rotationY(elapsedSeconds));
await asset.setTransform(Matrix4.rotationX(elapsedSeconds));

// Translate THEN rotate (order matters — matrix multiplication is not
// commutative; the rightmost operation applies first):
await asset.setTransform(Matrix4.translation(pos) * Matrix4.rotationY(angle));

// Orbit a moon around a planet at radius r:
final orbit = Matrix4.translation(Vector3(r * cos(t), 0, r * sin(t)));
await moon.setTransform(orbit);
```

## Per-frame movement (Flutter)

```dart
late Timer _timer;
final _started = DateTime.now();

_timer = Timer.periodic(const Duration(milliseconds: 16), (_) async {
  final elapsed =
      DateTime.now().difference(_started).inMilliseconds / 1000;
  await asset.setTransform(Matrix4.rotationY(elapsed));
});
// cancel in State.dispose()
```

## Scene-graph hierarchy

Parenting makes the child follow the parent:

```dart
await viewer.app.setParent(childEntity, parentEntity);

// Moving the parent now moves the child along with it:
await parentAsset.setTransform(Matrix4.translation(Vector3(-1, 0, 0)));
```

- Unparent with `setParent(childEntity, null)`.
- `preserveScaling: true` keeps the child's world scale when re-parenting.
- Query the graph: `getParent`, `getAncestor`, `getChildren`,
  `getChildCount` on the transform manager.

## TransformManager (lower level)

`viewer.app.transformManager` works on any entity, no asset required:

```dart
final tm = viewer.app.transformManager;

tm.setTransform(entity, Matrix4.identity());     // synchronous
await tm.setTransformAsync(entity, Matrix4.identity()); // applied on render thread

final Matrix4 local = tm.getLocalTransform(entity);   // relative to parent
final Matrix4 world = tm.getWorldTransform(entity);   // world space

tm.setParent(child, parent);
final children = tm.getChildren(entity);

// Batch many transform edits without intermediate recomputation:
tm.openLocalTransformTransaction();
// ... many setTransform calls ...
tm.commitLocalTransformTransaction();
```

`viewer.app.setTransform(entity, matrix)` and
`viewer.app.getLocalTransform(entity)` / `getWorldTransform(entity)` are
equivalent conveniences on the app.

## Camera movement is different

The camera is not moved with `setTransform` — aim it with
`camera.lookAt(position, focus: target)` (see the `thermion-camera-input`
skill).

## Gotchas

- `setTransform` replaces (not accumulates) — compose the full matrix you want.
- Matrix multiplication order matters: `A * B` applies B first.
- Euler angles are radians; `Quaternion.fromEulerAngles(x, y, z)` is the
  easiest rotation constructor.
- Scale is baked into the same matrix — a non-uniform scale changes how
  rotations look.
- The camera at the origin looks down −Z; +Y is up (right-handed).

## References

- `references/dart-hierarchy.dart` — complete pure-Dart program with a parent
  cube and a parented child cube that follows the parent's movement.

## Docs

- https://thermion.dev/entities/ — positions, movement, and hierarchy section
  of the Entities page
