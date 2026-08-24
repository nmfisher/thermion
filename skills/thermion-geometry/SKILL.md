---
name: thermion-geometry
description: >
  Create 3D geometry procedurally in Thermion without a glTF file. Covers
  GeometryUtils primitives (cube, sphere, cylinder, conic, plane, groundPlane,
  halfPyramid, fullscreenQuad, fromAabb3), building a custom Geometry from
  hand-specified vertex positions and triangle indices (plus normals, UVs,
  colors), turning geometry into a scene entity with viewer.createGeometry
  (optionally with your own material instances), and positioning the result.
  Use when you need a simple shape (cube, plane, sphere), a debug ground plane,
  a custom mesh from raw vertex data, or a bounding-box visualization.
  Triggers: geometry, primitive, cube, sphere, cylinder, cone, plane, ground
  plane, custom mesh, vertices, indices, triangle, procedural geometry,
  createGeometry, GeometryUtils, vertex buffer, draw a shape.
---

Not everything needs a glTF file. `GeometryUtils` provides ready-made
primitives; a `Geometry` object wraps raw vertex/index data; and
`viewer.createGeometry` turns either into a `ThermionAsset` in the scene —
positioned and transformed exactly like a loaded glTF.

## Primitives

```dart
final cube = await viewer.createGeometry(GeometryUtils.cube());
final sphere = await viewer.createGeometry(GeometryUtils.sphere());
final cylinder = await viewer.createGeometry(GeometryUtils.cylinder(uvs: false));
final cone = await viewer.createGeometry(GeometryUtils.conic(uvs: false));
final plane = await viewer.createGeometry(GeometryUtils.plane(width: 10, height: 10));
final ground = await viewer.createGeometry(GeometryUtils.groundPlane());

await cube.setTransform(Matrix4.translation(Vector3(-4, 0, 0)));
await sphere.setTransform(Matrix4.translation(Vector3(-2, 0, 0)));
```

Options: `cube(normals:, uvs:, flipUvs:)`,
`sphere(latitudeBands: 20, longitudeBands: 20)`, `cylinder(radius:, length:)`,
`conic(radius:, length:)`, `plane(width:, height:)`. By default primitives
generate normals + UVs (cylinder/conic take `uvs:` explicitly).

Bounding-box helper (debug visualization):

```dart
final boxMesh = await viewer.createGeometry(GeometryUtils.fromAabb3(bounds));
```

`viewer.showBoundingBox(asset)` / `viewer.hideBoundingBox(asset)` render an
asset's box directly.

## Custom geometry

Supply vertex positions (a flat `Float32List` of x,y,z triplets) and triangle
indices:

```dart
// A pyramid: 5 vertices, 6 triangles.
final vertices = Float32List.fromList([
  // Base (y = -1)
  -1.0, -1.0, -1.0, // 0
   1.0, -1.0, -1.0, // 1
   1.0, -1.0,  1.0, // 2
  -1.0, -1.0,  1.0, // 3
  // Apex (y = 1)
   0.0,  1.0,  0.0, // 4
]);
final indices = <int>[
  0, 2, 1,  0, 3, 2, // base (two triangles)
  0, 1, 4,  1, 2, 4,  // sides
  2, 3, 4,  3, 0, 4,
];

final geo = Geometry(vertices, indices);
final pyramid = await viewer.createGeometry(geo);
await pyramid.setTransform(Matrix4.translation(Vector3(0, 1, 0)));
```

Optional named parameters on `Geometry`:

```dart
Geometry(
  vertices, indices,
  normals: normalList,   // Float32List of x,y,z per vertex
  uvs: uvList,           // Float32List of u,v per vertex
  colors: colorList,     // Float32List of r,g,b[,a] per vertex
  primitiveType: PrimitiveType.TRIANGLES,
  // createDummyColors/createDummyUvs/createDummyUvs1 pad missing attributes
);
```

## Materials at creation time

Without a material the default ubershader is used. Pass material instances to
control appearance (create them first — see the `thermion-materials` skill):

```dart
final material = await viewer.app.createUbershaderMaterial();
await material.setBaseColorFactor(0.8, 0.2, 0.2, 1.0);

final asset = await viewer.createGeometry(
  GeometryUtils.sphere(),
  materialInstances: [material.materialInstance],
);
```

`materialInstances` is a list — one entry per primitive (primitives from
`GeometryUtils` are single-primitive).

## Gotchas

- Winding order matters: counter-clockwise when viewed from outside
  (front-facing). Back faces are culled by default.
- One position = one vertex — duplicate vertices at sharp edges if you want
  per-face normals.
- Geometry assets are `ThermionAsset`s: `setTransform`, `setCastShadows`,
  `destroyAsset`, instancing-free but otherwise the same lifecycle as glTF.
- Wireframe rendering of custom geometry needs barycentric-duplicated
  vertices: `GeometryUtils.duplicateVerticesWithBarycentrics(vertices, indices)`.

## References

- `references/dart-primitives-and-pyramid.dart` — complete pure-Dart program:
  the five primitives in a row plus a hand-built pyramid.

## Docs

- https://thermion.dev/materials/ includes procedural geometry; the bundled
  reference and `examples/dart/examples_lib/lib/src/geometry_primitives.dart`
  / `custom_geometry.dart` in the thermion repository are canonical.
