import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';

class SphereGeometry {
  static Geometry sphere({bool normals = true, bool uvs = true}) {
    int latitudeBands = 20;
    int longitudeBands = 20;

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

        uvsList.addAll([
          longNumber / longitudeBands,
          latNumber / latitudeBands,
        ]);
      }
    }

    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = (latNumber * (longitudeBands + 1)) + longNumber;
        int second = first + longitudeBands + 1;

        indices.addAll([
          first,
          second,
          first + 1,
          second,
          second + 1,
          first + 1,
        ]);
      }
    }

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(
      vertices,
      Uint16List.fromList(indices),
      normals: _normals,
      uvs: _uvs,
    );
  }
}
