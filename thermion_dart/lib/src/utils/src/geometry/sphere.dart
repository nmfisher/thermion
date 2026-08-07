import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';

class SphereGeometry {
  static Geometry sphere({bool normals = true, bool uvs = true, int latitudeBands = 20, int longitudeBands = 20}) {
    if (latitudeBands < 2) {
      throw ArgumentError.value(latitudeBands, 'latitudeBands', 'must be >= 2');
    }
    if (longitudeBands < 3) {
      throw ArgumentError.value(longitudeBands, 'longitudeBands', 'must be >= 3');
    }

    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
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

        verticesList.addAll([x, y, z]);
        normalsList.addAll([x, y, z]);

        uvsList.addAll([longNumber / longitudeBands, latNumber / latitudeBands]);
      }
    }

    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = (latNumber * (longitudeBands + 1)) + longNumber;
        int second = first + longitudeBands + 1;

        // Each longitude has its own copy of the pole so that the UV seam can
        // remain split. Do not emit the collapsed half of the quad at either
        // pole: zero-area triangles make tangent-frame generation unstable,
        // which is especially visible on low-roughness PBR materials.
        if (latNumber != 0) {
          indices.addAll([first, first + 1, second]);
        }
        if (latNumber != latitudeBands - 1) {
          indices.addAll([second, first + 1, second + 1]);
        }
      }
    }

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, Uint16List.fromList(indices), normals: _normals, uvs: _uvs);
  }
}
