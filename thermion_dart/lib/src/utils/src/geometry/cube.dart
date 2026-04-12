import 'package:thermion_dart/thermion_dart.dart';

class CubeGeometry {
  static Geometry cube(
      {bool normals = true, bool uvs = true, bool flipUvs = true}) {
    final vertices = Float32List.fromList([
      // Front face
      -1, -1, 1,
      1, -1, 1,
      1, 1, 1,
      -1, 1, 1,

      // Back face
      -1, -1, -1,
      1, -1, -1,
      1, 1, -1,
      -1, 1, -1,

      // Top face
      -1, 1, 1,
      1, 1, 1,
      1, 1, -1,
      -1, 1, -1,

      // Bottom
      -1, -1, -1,
      1, -1, -1,
      1, -1, 1,
      -1, -1, 1,

      // Right
      1, -1, 1,
      1, -1, -1,
      1, 1, -1,
      1, 1, 1,

      // Left
      -1, -1, -1,
      -1, -1, 1,
      -1, 1, 1,
      -1, 1, -1,
    ]);

    final _normals = normals
        ? Float32List.fromList([
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,
            0, 1, 0,
            0, 1, 0,
            0, 1, 0,
            0, 1, 0,
            0, -1, 0,
            0, -1, 0,
            0, -1, 0,
            0, -1, 0,
            1, 0, 0,
            1, 0, 0,
            1, 0, 0,
            1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
          ])
        : null;

    var originalUvs = <double>[
      // front
      1 / 3, 3 / 4,
      2 / 3, 3 / 4,
      2 / 3, 1,
      1 / 3, 1,

      // back
      1 / 3, 1 / 4,
      2 / 3, 1 / 4,
      2 / 3, 1 / 2,
      1 / 3, 1 / 2,

      // top
      2 / 3, 1 / 2,
      1, 1 / 2,
      1, 3 / 4,
      2 / 3, 3 / 4,

      // bottom
      0, 1 / 2,
      1 / 3, 1 / 2,
      1 / 3, 3 / 4,
      0, 3 / 4,

      // right
      1 / 3, 1 / 2,
      2 / 3, 1 / 2,
      2 / 3, 3 / 4,
      1 / 3, 3 / 4,

      // left
      1 / 3, 0,
      2 / 3, 0,
      2 / 3, 1 / 4,
      1 / 3, 1 / 4,
    ];

    final _uvs = uvs
        ? Float32List.fromList(
            flipUvs ? _flipUvCoordinates(originalUvs) : originalUvs)
        : null;

    final indices = [
      0, 1, 2, 0, 2, 3,
      5, 4, 7, 5, 7, 6,
      8, 9, 10, 8, 10, 11,
      12, 13, 14, 12, 14, 15,
      16, 17, 18, 16, 18, 19,
      20, 21, 22, 20, 22, 23,
    ];

    return Geometry(vertices, Uint16List.fromList(indices),
        normals: _normals, uvs: _uvs);
  }

  static List<double> _flipUvCoordinates(List<double> uvs) {
    var flippedUvs = List<double>.from(uvs);
    for (var i = 1; i < flippedUvs.length; i += 2) {
      flippedUvs[i] = 1.0 - flippedUvs[i];
    }
    return flippedUvs;
  }
}
