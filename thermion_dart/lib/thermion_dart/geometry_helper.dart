import 'dart:math';

class Geometry {
  final List<double> vertices;
  final List<int> indices;
  final List<double> normals;

  Geometry(this.vertices, this.indices, this.normals);
}

class GeometryHelper {
  static Geometry sphere() {
    int latitudeBands = 20;
    int longitudeBands = 20;

    List<double> vertices = [];
    List<double> normals = [];
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
        normals.addAll([x, y, z]); // For a sphere, normals are the same as vertex positions
      }
    }

    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = (latNumber * (longitudeBands + 1)) + longNumber;
        int second = first + longitudeBands + 1;

        indices.addAll([first, second, first + 1, second, second + 1, first + 1]);
      }
    }

    return Geometry(vertices, indices, normals);
  }

  static Geometry cube() {
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

    final normals = <double>[
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
      0, 3, 2, 0, 2, 1,
      // Back face
      4, 7, 6, 4, 6, 5,
      // Top face
      8, 11, 10, 8, 10, 9,
      // Bottom face
      12, 15, 14, 12, 14, 13,
      // Right face
      16, 19, 18, 16, 18, 17,
      // Left face
      20, 23, 22, 20, 22, 21
    ];

    return Geometry(vertices, indices, normals);
  }
}