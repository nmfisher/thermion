import 'package:thermion_dart/thermion_dart.dart';

class PyramidGeometry {
  static Geometry halfPyramid(
      {double startX = 0.25,
      double startY = 0.25,
      double width = 1.0,
      double height = 1.0,
      double depth = 1.0,
      bool normals = true,
      bool uvs = true}) {
    Float32List vertices = Float32List.fromList([
      startX, startY, 0,
      startX + width, startY, 0,
      startX + width, startY + height, 0,
      startX, startY + height, 0,
      startX, startY + height, depth,
      startX + width, startY + height, depth,
    ]);

    Float32List? _normals = normals
        ? Float32List.fromList([
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,
            0, 0.7071, 0.7071,
            0, 0.7071, 0.7071,
          ])
        : null;

    Float32List? _uvs = uvs
        ? Float32List.fromList([
            0, 0,
            1, 0,
            1, 1,
            0, 1,
            0, 0.5,
            1, 0.5,
          ])
        : null;

    Uint16List indices = Uint16List.fromList([
      0, 1, 2,
      0, 2, 3,
      0, 1, 5,
      0, 5, 4,
      0, 4, 3,
      1, 2, 5,
      2, 3, 4,
      2, 4, 5,
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }
}
