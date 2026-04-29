import 'package:thermion_dart/thermion_dart.dart';

class PlaneGeometry {
  static Geometry plane(
      {double width = 1.0,
      double height = 1.0,
      bool normals = true,
      bool uvs = true}) {
    Float32List vertices = Float32List.fromList([
      -width / 2,
      0,
      -height / 2,
      width / 2,
      0,
      -height / 2,
      width / 2,
      0,
      height / 2,
      -width / 2,
      0,
      height / 2,
    ]);

    Float32List? _normals = normals
        ? Float32List.fromList([
            0,
            1,
            0,
            0,
            1,
            0,
            0,
            1,
            0,
            0,
            1,
            0,
          ])
        : null;

    Float32List? _uvs = uvs
        ? Float32List.fromList([
            0,
            0,
            1,
            0,
            1,
            1,
            0,
            1,
          ])
        : null;

    final indices = Uint16List.fromList([
      0,
      1,
      2,
      0,
      2,
      3,
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry groundPlane({bool normals = true, bool uvs = true}) {
    final vertices = Float32List.fromList([
      -1, 0, 1,  // 0: front-left
      1, 0, 1,   // 1: front-right
      1, 0, -1,  // 2: back-right
      -1, 0, -1, // 3: back-left
    ]);

    final Float32List? _normals = normals
        ? Float32List.fromList([
            0, 1, 0,  // Normal for vertex 0
            0, 1, 0,  // Normal for vertex 1
            0, 1, 0,  // Normal for vertex 2
            0, 1, 0,  // Normal for vertex 3
          ])
        : null;

    final Float32List? _uvs = uvs
        ? Float32List.fromList([
            0, 1,  // UV for vertex 0 (bottom-left)
            1, 1,  // UV for vertex 1 (bottom-right)
            1, 0,  // UV for vertex 2 (top-right)
            0, 0,  // UV for vertex 3 (top-left)
          ])
        : null;

    final indices = Uint16List.fromList([
      0, 1, 2,  // First triangle (front-right half)
      0, 2, 3,  // Second triangle (back-left half)
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry quad() {
    final vertices = Float32List.fromList([
      -1, -1, 1, // 0
      1, -1, 1, // 1
      1, 1, 1, // 2
      -1, 1, 1, // 3
    ]);
    final normals = Float32List.fromList([0, 0, 1, 0, 0, 1]);
    final indices = Uint16List.fromList([
      0,
      1,
      2,
      0,
      2,
      3,
    ]);
    final uvs = Float32List.fromList([
      0, 1, 1, 1, 1, 0, 0, 0
    ]);
    return Geometry(vertices, indices,
      // normals: normals,
      uvs: uvs
    );
  }
}
