import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';

class CylinderGeometry {
  static Geometry cylinder({
    double radius = 1.0,
    double length = 1.0,
    bool normals = true,
    bool uvs = true,
  }) {
    int segments = 32;
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    for (int i = 0; i <= segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      verticesList.addAll([x, length / 2, z]);
      normalsList.addAll([x / radius, 0, z / radius]);
      uvsList.addAll([i / segments, 1]);

      verticesList.addAll([x, -length / 2, z]);
      normalsList.addAll([x / radius, 0, z / radius]);
      uvsList.addAll([i / segments, 0]);
    }

    for (int i = 0; i < segments; i++) {
      int topFirst = i * 2;
      int topSecond = (i + 1) * 2;
      int bottomFirst = topFirst + 1;
      int bottomSecond = topSecond + 1;

      // Cap centers are appended after the rim loop, at (segments + 1) * 2.
      indices.addAll([(segments + 1) * 2, topSecond, topFirst]);
      indices.addAll([(segments + 1) * 2 + 1, bottomFirst, bottomSecond]);
      indices.addAll([topFirst, topSecond, bottomFirst]);
      indices.addAll([bottomFirst, topSecond, bottomSecond]);
    }

    verticesList.addAll([0, length / 2, 0]);
    normalsList.addAll([0, 1, 0]);
    uvsList.addAll([0.5, 0.5]);

    verticesList.addAll([0, -length / 2, 0]);
    normalsList.addAll([0, -1, 0]);
    uvsList.addAll([0.5, 0.5]);

    for (int i = 0; i <= segments; i++) {
      normalsList.addAll([0, 1, 0]);
      normalsList.addAll([0, -1, 0]);

      double u = 0.5 + 0.5 * cos(i * 2 * pi / segments);
      double v = 0.5 + 0.5 * sin(i * 2 * pi / segments);
      uvsList.addAll([u, v]);
      uvsList.addAll([u, v]);
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

  static Geometry conic({
    double radius = 1.0,
    double length = 1.0,
    bool normals = true,
    bool uvs = true,
  }) {
    int segments = 32;
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    verticesList.addAll([0, length, 0]);
    if (normals) {
      normalsList.addAll([0, 1, 0]);
    }
    if (uvs) {
      uvsList.addAll([0.5, 1]);
    }

    for (int i = 0; i <= segments; i++) {
      double theta = (i % segments) * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      verticesList.addAll([x, 0, z]);

      if (normals) {
        double slantX = -x;
        double slantY = length;
        double slantZ = -z;

        double tangentX = -z;
        double tangentY = 0;
        double tangentZ = x;

        double nx = (tangentY * slantZ) - (tangentZ * slantY);
        double ny = (tangentZ * slantX) - (tangentX * slantZ);
        double nz = (tangentX * slantY) - (tangentY * slantX);

        double normalLength = sqrt(nx * nx + ny * ny + nz * nz);
        nx /= normalLength;
        ny /= normalLength;
        nz /= normalLength;

        normalsList.addAll([nx, ny, nz]);
      }

      if (uvs) {
        uvsList.addAll([i / segments, 0]);
      }
    }

    for (int i = 0; i < segments; i++) {
      int current = i + 1;
      int next = ((i + 1) % segments) + 1;
      indices.addAll([0, next, current]);
    }

    int baseStartIndex = verticesList.length ~/ 3;

    verticesList.addAll([0, 0, 0]);
    if (normals) {
      normalsList.addAll([0, -1, 0]);
    }
    if (uvs) {
      uvsList.addAll([0.5, 0.5]);
    }

    for (int i = 0; i < segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      verticesList.addAll([x, 0, z]);

      if (normals) {
        normalsList.addAll([0, -1, 0]);
      }

      if (uvs) {
        double u = 0.5 + 0.5 * cos(theta);
        double v = 0.5 + 0.5 * sin(theta);
        uvsList.addAll([u, v]);
      }
    }

    for (int i = 0; i < segments; i++) {
      int current = baseStartIndex + 1 + i;
      int next = baseStartIndex + 1 + ((i + 1) % segments);
      indices.addAll([baseStartIndex, current, next]);
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
