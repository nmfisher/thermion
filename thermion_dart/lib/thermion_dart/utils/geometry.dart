import 'dart:math';

import 'package:thermion_dart/thermion_dart/viewer/shared_types/geometry.dart';

class GeometryHelper {
  static Geometry sphere({bool normals = true, bool uvs = true}) {
    int latitudeBands = 20;
    int longitudeBands = 20;

    List<double> vertices = [];
    List<double> _normals = [];
    List<int> indices = [];

    for (int latNumber = 0; latNumber <= latitudeBands; latNumber++) {
      double theta = latNumber * pi / latitudeBands;
      double sinTheta = sin(theta);
      double cosTheta = cos(theta);

      for (int longNumber = 0; longNumber <= longitudeBands; longNumber++) {
        double phi = longNumber * 2 * pi / longitudeBands;
        double sinPhi = sin(phi);
        double cosPhi = cos(phi);

        double x = cosPhi * sinTheta;
        double y = cosTheta;
        double z = sinPhi * sinTheta;

        vertices.addAll([x, y, z]);
        _normals.addAll([
          x,
          y,
          z
        ]); // For a sphere, normals are the same as vertex positions
      }
    }

    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = (latNumber * (longitudeBands + 1)) + longNumber;
        int second = first + longitudeBands + 1;

        indices
            .addAll([first, second, first + 1, second, second + 1, first + 1]);
      }
    }

    return Geometry(vertices, indices, normals: normals ? _normals : null);
  }

  static Geometry cube({bool normals = true, bool uvs = true}) {
    final vertices = <double>[
      // Front face
      -1, -1, 1,
      1, -1, 1,
      1, 1, 1,
      -1, 1, 1,

      // Back face
      -1, -1, -1,
      -1, 1, -1,
      1, 1, -1,
      1, -1, -1,

      // Top face
      -1, 1, -1,
      -1, 1, 1,
      1, 1, 1,
      1, 1, -1,

      // Bottom face
      -1, -1, -1,
      1, -1, -1,
      1, -1, 1,
      -1, -1, 1,

      // Right face
      1, -1, -1,
      1, 1, -1,
      1, 1, 1,
      1, -1, 1,

      // Left face
      -1, -1, -1,
      -1, -1, 1,
      -1, 1, 1,
      -1, 1, -1,
    ];

    final _normals = <double>[
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
    ];

    final indices = [
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
    ];
    return Geometry(vertices, indices, normals: normals ? _normals : null);
  }

  static Geometry cylinder({double radius = 1.0, double length = 1.0, bool normals = true, bool uvs = true }) {
    int segments = 32;
    List<double> vertices = [];
    List<double> _normals = [];
    List<int> indices = [];

    // Create vertices and normals
    for (int i = 0; i <= segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      // Top circle
      vertices.addAll([x, length / 2, z]);
      _normals.addAll([x / radius, 0, z / radius]);

      // Bottom circle
      vertices.addAll([x, -length / 2, z]);
      _normals.addAll([x / radius, 0, z / radius]);
    }

    // Create indices
    for (int i = 0; i < segments; i++) {
      int topFirst = i * 2;
      int topSecond = (i + 1) * 2;
      int bottomFirst = topFirst + 1;
      int bottomSecond = topSecond + 1;

      // Top face (counter-clockwise)
      indices.addAll([segments * 2, topSecond, topFirst]);
      // Bottom face (counter-clockwise when viewed from below)
      indices.addAll([segments * 2 + 1, bottomFirst, bottomSecond]);
      // Side faces (counter-clockwise)
      indices.addAll([topFirst, bottomFirst, topSecond]);
      indices.addAll([bottomFirst, bottomSecond, topSecond]);
    }

    // Add center vertices and normals for top and bottom faces
    vertices.addAll([0, length / 2, 0]); // Top center
    _normals.addAll([0, 1, 0]);
    vertices.addAll([0, -length / 2, 0]); // Bottom center
    _normals.addAll([0, -1, 0]);

    // Add top and bottom face normals
    for (int i = 0; i <= segments; i++) {
      _normals.addAll([0, 1, 0]); // Top face normal
      _normals.addAll([0, -1, 0]); // Bottom face normal
    }

    return Geometry(vertices, indices, normals: normals ? _normals : null);
  }

  static Geometry conic({double radius = 1.0, double length = 1.0, bool normals = true, bool uvs = true}) {
    int segments = 32;
    List<double> vertices = [];
    List<double> _normals = [];
    List<int> indices = [];

    // Create vertices and normals
    for (int i = 0; i <= segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      // Base circle
      vertices.addAll([x, 0, z]);

      // Calculate normal for the side
      double nx = x / sqrt(x * x + length * length);
      double nz = z / sqrt(z * z + length * length);
      double ny = radius / sqrt(radius * radius + length * length);
      _normals.addAll([nx, ny, nz]);
    }
    // Apex
    vertices.addAll([0, length, 0]);
    _normals.addAll([0, 1, 0]); // Normal at apex points straight up

    // Create indices
    for (int i = 0; i < segments; i++) {
      // Base face (fixed to counterclockwise)
      indices.addAll([segments + 1, i + 1, i]);
      // Side faces (already correct)
      indices.addAll([i, segments, i + 1]);
    }

    // Add base face normals
    for (int i = 0; i <= segments; i++) {
      _normals.addAll([0, -1, 0]); // Base face normal
    }

    return Geometry(vertices, indices, normals: normals ? _normals : null);
  }

  static Geometry plane({double width = 1.0, double height = 1.0, bool normals = true, bool uvs = true}) {
    List<double> vertices = [
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
    ];

    List<double> _normals = [
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
    ];

    List<int> indices = [
      0,
      2,
      1,
      0,
      3,
      2,
    ];

    return Geometry(vertices, indices, normals: normals ? _normals : null);
  }
}
