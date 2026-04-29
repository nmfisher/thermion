import 'package:thermion_dart/thermion_dart.dart';

class AabbGeometry {
  static Geometry fromAabb3(Aabb3 aabb,
      {bool normals = true, bool uvs = true}) {
    // Get the center and half extents from the AABB
    final center = aabb.center;
    final halfExtents = Vector3.zero();
    aabb.copyCenterAndHalfExtents(center, halfExtents);

    // Create vertices list with transformed coordinates
    final vertices = Float32List.fromList([
      // Front face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,

      // Back face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,

      // Top face
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,

      // Bottom face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,

      // Right face
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,

      // Left face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
    ]);

    final _normals = normals
        ? Float32List.fromList([
            // Front face
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,

            // Back face
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,

            // Top face
            0, 1, 0,
            0, 1, 0,
            0, 1, 0,
            0, 1, 0,

            // Bottom face
            0, -1, 0,
            0, -1, 0,
            0, -1, 0,
            0, -1, 0,

            // Right face
            1, 0, 0,
            1, 0, 0,
            1, 0, 0,
            1, 0, 0,

            // Left face
            -1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
          ])
        : null;

    final _uvs = uvs
        ? Float32List.fromList([
            // Front face
            1 / 3, 1 / 3,
            2 / 3, 1 / 3,
            2 / 3, 2 / 3,
            1 / 3, 2 / 3,

            // Back face
            2 / 3, 2 / 3,
            2 / 3, 1,
            1, 1,
            1, 2 / 3,

            // Top face
            1 / 3, 0,
            1 / 3, 1 / 3,
            2 / 3, 1 / 3,
            2 / 3, 0,

            // Bottom face
            1 / 3, 2 / 3,
            2 / 3, 2 / 3,
            2 / 3, 1,
            1 / 3, 1,

            // Right face
            2 / 3, 1 / 3,
            2 / 3, 2 / 3,
            1, 2 / 3,
            1, 1 / 3,

            // Left face
            0, 1 / 3,
            1 / 3, 1 / 3,
            1 / 3, 2 / 3,
            0, 2 / 3,
          ])
        : null;

    final indices = Uint16List.fromList([
      // Front face
      0, 1, 2, 0, 2, 3,
      // Back face
      4, 5, 6, 4, 6, 7,
      // Top face
      8, 9, 10, 8, 10, 11,
      // Bottom face
      12, 13, 14, 12, 14, 15,
      // Right face
      16, 17, 18, 16, 18, 19,
      // Left face
      20, 21, 22, 20, 22, 23
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }
}
