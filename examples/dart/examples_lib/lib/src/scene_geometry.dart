import 'package:thermion_dart/thermion_dart.dart';

/// Procedural-geometry showcase: the five [GeometryUtils] primitives, a
/// hand-authored custom pyramid, GPU-instanced cubes, and a parent/child
/// scene-graph pair -- arranged across a ground plane.
///
/// Absorbs geometry_primitives + custom_geometry + instancing +
/// transforms_and_hierarchy.
Future<void> setupGeometry(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 4.5, 12), focus: Vector3(0, 0.5, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.4)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  // Five primitives across the back row (cube, sphere, cylinder, cone, plane).
  final primitives = <(Geometry, Vector3)>[
    (GeometryUtils.cube(), Vector3(-6, 0.5, -1)),
    (GeometryUtils.sphere(), Vector3(-3, 0.5, -1)),
    (GeometryUtils.cylinder(uvs: false), Vector3(0, 0.5, -1)),
    (GeometryUtils.conic(uvs: false), Vector3(3, 0.5, -1)),
    (GeometryUtils.plane(), Vector3(6, 0.5, -1)),
  ];
  for (final (geo, pos) in primitives) {
    final e = await viewer.createGeometry(geo);
    await e.setTransform(Matrix4.translation(pos));
  }

  // Custom pyramid (hand-specified vertices), front-left.
  final verts = Float32List.fromList([
    -1.0, -1.0, -1.0, // 0
     1.0, -1.0, -1.0, // 1
     1.0, -1.0,  1.0, // 2
    -1.0, -1.0,  1.0, // 3
     0.0,  1.5,  0.0, // 4 apex
  ]);
  final idx = <int>[
    0, 2, 1, 0, 3, 2, // base
    0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, // sides
  ];
  final pyramid = await viewer.createGeometry(Geometry(verts, idx));
  await pyramid.setTransform(
    Matrix4.translation(Vector3(-5, 0.5, 4)) *
        Matrix4.diagonal3(Vector3.all(0.6)),
  );

  // GPU-instanced cubes (one draw call), front-center.
  final inst = await viewer.loadGltf("$assetsDir/cube.glb", initialInstances: 3);
  await inst.transformToUnitCube();
  for (var i = 0; i < 3; i++) {
    final ii = await inst.getInstance(i);
    await ii.setTransform(
      Matrix4.translation(Vector3(-1.5 + i * 1.5, 0.5, 4)) *
          Matrix4.diagonal3(Vector3.all(0.6)),
    );
  }

  // Parent/child hierarchy, front-right: parenting the child means moving the
  // parent drags the child along.
  final parent = await viewer.loadGltf("$assetsDir/cube.glb");
  await parent.transformToUnitCube();
  final child = await viewer.loadGltf("$assetsDir/cube.glb");
  await child.transformToUnitCube();
  await child.setTransform(
    Matrix4.translation(Vector3(0.9, 0, 0)) *
        Matrix4.diagonal3(Vector3.all(0.5)),
  );
  await viewer.app.setParent(child.entity, parent.entity);
  await parent.setTransform(
    Matrix4.translation(Vector3(4.5, 0.5, 4)) *
        Matrix4.diagonal3(Vector3.all(0.8)),
  );
}
