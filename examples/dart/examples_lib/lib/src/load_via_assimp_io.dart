import 'package:assimp_dart/assimp_dart.dart' hide PrimitiveType;
import 'package:thermion_dart/thermion_dart.dart';

/// Reference consumer-side glue between assimp_dart and thermion (native).
///
/// thermion ships no model-file importer of its own (and deliberately does
/// not depend on assimp_dart): multi-format loading (OBJ, FBX, STL, PLY, ...)
/// lives in the standalone assimp_dart package, and consumers bridge the two
/// themselves. This setup is that bridge:
///
/// 1. load the model bytes through the configured resource loader and parse
///    them with `AssimpImporter` into [RawMesh]es (flat, world-space meshes
///    whose typed-data views point into native memory owned by the mesh),
/// 2. build a thermion [Geometry] from each mesh's positions/normals/uvs/
///    indices (flipping UVs here — never in native — because most model
///    formats use a bottom-left UV origin while Filament uses top-left),
/// 3. upload with `createGeometry`, which copies the buffers on the render
///    thread before its future resolves,
/// 4. `dispose` each [RawMesh] exactly once after the upload — the typed-data
///    views point into native memory, so they must not be read afterwards.
Future<void> setupLoadViaAssimp(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );

  final data = await FilamentApp.instance!.loadResource("$assetsDir/test_cube.obj");
  final meshes = AssimpImporter().parse(data, formatHint: 'obj');

  try {
    for (final mesh in meshes) {
      final asset = await viewer.createGeometry(_meshToGeometry(mesh, flipUvs: true));
      await asset.transformToUnitCube();
    }
  } finally {
    // createGeometry's uploads copy the bytes before their futures resolve,
    // so the native buffers behind the meshes' views are no longer needed.
    for (final mesh in meshes) {
      mesh.dispose();
    }
  }

  await camera.lookAt(Vector3(3.0, 3.0, 3.0), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
}

/// Converts one parsed [RawMesh] into a thermion [Geometry].
///
/// The geometry's positions/normals/uvs are the SAME typed-data views the
/// mesh exposes (no copy); only UV flipping and USHORT index narrowing
/// allocate. Keep the mesh undisposed until the geometry has been uploaded.
Geometry _meshToGeometry(RawMesh mesh, {bool flipUvs = false}) {
  final Float32List? processedUvs;
  if (mesh.uvs.isEmpty) {
    processedUvs = null;
  } else {
    // Flipping happens here only, never in native Assimp, so it is never
    // double-applied.
    processedUvs = flipUvs ? RawMesh.flipUVs(mesh.uvs) : mesh.uvs;
  }

  final indexType = mesh.indices.length <= 65535 ? IndexType.USHORT : IndexType.UINT;
  final List<int> indices;
  if (indexType == IndexType.USHORT) {
    // Narrow through a typed list — no boxed per-element allocation.
    indices = Uint16List.fromList(mesh.indices);
  } else {
    indices = mesh.indices;
  }

  // Both PrimitiveType enums mirror the GL constants in the same order
  // (filament's DriverEnums.h and assimp_dart's raw_mesh.dart), so a
  // positional map is exact.
  return Geometry(
    mesh.positions,
    indices,
    normals: mesh.normals.isEmpty ? null : mesh.normals,
    uvs: processedUvs,
    primitiveType: PrimitiveType.values[mesh.primitiveType.index],
    indexType: indexType,
  );
}
