import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';

class CameraGeometry {
  static Geometry camera({
    double bodyWidth = 0.6,
    double bodyHeight = 0.7,
    double bodyDepth = 1.4,
    double lensRadius = 0.3,
    double lensLength = 0.4,
    bool normals = true,
    bool uvs = true,
  }) {
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    void addVertex(double x, double y, double z, double nx, double ny,
        double nz, double u, double v) {
      verticesList.addAll([x, y, z]);
      if (normals) normalsList.addAll([nx, ny, nz]);
      if (uvs) uvsList.addAll([u, v]);
    }

    int currentIndex = 0;

    double halfWidth = bodyWidth / 2;
    double halfHeight = bodyHeight / 2;
    double halfDepth = bodyDepth / 2;

    // Front face - Z = +halfDepth
    addVertex(-halfWidth, -halfHeight, halfDepth, 0, 0, 1, 0, 0);
    addVertex(halfWidth, -halfHeight, halfDepth, 0, 0, 1, 1, 0);
    addVertex(halfWidth, halfHeight, halfDepth, 0, 0, 1, 1, 1);
    addVertex(-halfWidth, halfHeight, halfDepth, 0, 0, 1, 0, 1);

    // Back face - Z = -halfDepth
    addVertex(halfWidth, -halfHeight, -halfDepth, 0, 0, -1, 0, 0);
    addVertex(-halfWidth, -halfHeight, -halfDepth, 0, 0, -1, 1, 0);
    addVertex(-halfWidth, halfHeight, -halfDepth, 0, 0, -1, 1, 1);
    addVertex(halfWidth, halfHeight, -halfDepth, 0, 0, -1, 0, 1);

    // Top face - Y = +halfHeight
    addVertex(-halfWidth, halfHeight, halfDepth, 0, 1, 0, 0, 0);
    addVertex(halfWidth, halfHeight, halfDepth, 0, 1, 0, 1, 0);
    addVertex(halfWidth, halfHeight, -halfDepth, 0, 1, 0, 1, 1);
    addVertex(-halfWidth, halfHeight, -halfDepth, 0, 1, 0, 0, 1);

    // Bottom face - Y = -halfHeight
    addVertex(-halfWidth, -halfHeight, -halfDepth, 0, -1, 0, 0, 0);
    addVertex(halfWidth, -halfHeight, -halfDepth, 0, -1, 0, 1, 0);
    addVertex(halfWidth, -halfHeight, halfDepth, 0, -1, 0, 1, 1);
    addVertex(-halfWidth, -halfHeight, halfDepth, 0, -1, 0, 0, 1);

    // Right face - X = +halfWidth
    addVertex(halfWidth, -halfHeight, halfDepth, 1, 0, 0, 0, 0);
    addVertex(halfWidth, -halfHeight, -halfDepth, 1, 0, 0, 1, 0);
    addVertex(halfWidth, halfHeight, -halfDepth, 1, 0, 0, 1, 1);
    addVertex(halfWidth, halfHeight, halfDepth, 1, 0, 0, 0, 1);

    // Left face - X = -halfWidth
    addVertex(-halfWidth, -halfHeight, -halfDepth, -1, 0, 0, 0, 0);
    addVertex(-halfWidth, -halfHeight, halfDepth, -1, 0, 0, 1, 0);
    addVertex(-halfWidth, halfHeight, halfDepth, -1, 0, 0, 1, 1);
    addVertex(-halfWidth, halfHeight, -halfDepth, -1, 0, 0, 0, 1);

    List<int> bodyIndices = [
      0,
      1,
      2,
      0,
      2,
      3,
      4,
      5,
      6,
      4,
      6,
      7,
      8,
      9,
      10,
      8,
      10,
      11,
      12,
      13,
      14,
      12,
      14,
      15,
      16,
      17,
      18,
      16,
      18,
      19,
      20,
      21,
      22,
      20,
      22,
      23
    ];

    indices.addAll(bodyIndices);
    currentIndex = 24;

    // Conical lens
    int segments = 16;
    double lensApexZ = -halfDepth;
    double lensBaseZ = -halfDepth - lensLength;

    addVertex(0, 0, lensApexZ, 0, 0, -1, 0.5, 0);
    int apexIndex = currentIndex;
    currentIndex++;

    List<int> baseIndices = [];
    for (int i = 0; i < segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = lensRadius * cos(theta);
      double y = lensRadius * sin(theta);

      double normalX = x / lensRadius;
      double normalY = y / lensRadius;
      double normalZ = lensRadius / lensLength;

      double normalLength =
          sqrt(normalX * normalX + normalY * normalY + normalZ * normalZ);
      normalX /= normalLength;
      normalY /= normalLength;
      normalZ /= normalLength;

      addVertex(x, y, lensBaseZ, normalX, normalY, normalZ, i / segments, 1);
      baseIndices.add(currentIndex);
      currentIndex++;
    }

    for (int i = 0; i < segments; i++) {
      int current = baseIndices[i];
      int next = baseIndices[(i + 1) % segments];
      indices.addAll([apexIndex, next, current]);
    }

    // Lens base (flat circular face)
    addVertex(0, 0, lensBaseZ, 0, 0, 1, 0.5, 0.5);
    int baseCenterIndex = currentIndex;
    currentIndex++;

    List<int> baseFaceIndices = [];
    for (int i = 0; i < segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = lensRadius * cos(theta);
      double y = lensRadius * sin(theta);

      double u = 0.5 + 0.5 * cos(theta);
      double v = 0.5 + 0.5 * sin(theta);

      addVertex(x, y, lensBaseZ, 0, 0, 1, u, v);
      baseFaceIndices.add(currentIndex);
      currentIndex++;
    }

    for (int i = 0; i < segments; i++) {
      int current = baseFaceIndices[i];
      int next = baseFaceIndices[(i + 1) % segments];
      indices.addAll([baseCenterIndex, current, next]);
    }

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, Uint16List.fromList(indices),
        normals: _normals, uvs: _uvs);
  }

  static Geometry wireframeCamera({
    double sphereRadius = 0.2,
    double frustumDistance = 1.0,
    double frustumNear = 0.5,
    double frustumFar = 1.0,
    double fov = pi / 3,
    bool normals = true,
    bool uvs = true,
    double wireThickness = 0.01,
  }) {
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    void addWireSegment(List<double> start, List<double> end) {
      int baseIndex = verticesList.length ~/ 3;

      double dx = end[0] - start[0];
      double dy = end[1] - start[1];
      double dz = end[2] - start[2];

      List<double> perp1, perp2;
      if (dx.abs() < 0.9) {
        perp1 = [0, -dz, dy];
      } else {
        perp1 = [-dy, dx, 0];
      }

      double perpLength =
          sqrt(perp1[0] * perp1[0] + perp1[1] * perp1[1] + perp1[2] * perp1[2]);
      if (perpLength > 0) {
        perp1 = [
          perp1[0] / perpLength * wireThickness,
          perp1[1] / perpLength * wireThickness,
          perp1[2] / perpLength * wireThickness
        ];
      }

      perp2 = [
        dy * perp1[2] - dz * perp1[1],
        dz * perp1[0] - dx * perp1[2],
        dx * perp1[1] - dy * perp1[0]
      ];

      List<List<double>> startVerts = [
        [start[0] + perp1[0], start[1] + perp1[1], start[2] + perp1[2]],
        [start[0] - perp1[0], start[1] - perp1[1], start[2] - perp1[2]],
        [start[0] + perp2[0], start[1] + perp2[1], start[2] + perp2[2]],
        [start[0] - perp2[0], start[1] - perp2[1], start[2] - perp2[2]],
      ];

      List<List<double>> endVerts = [
        [end[0] + perp1[0], end[1] + perp1[1], end[2] + perp1[2]],
        [end[0] - perp1[0], end[1] - perp1[1], end[2] - perp1[2]],
        [end[0] + perp2[0], end[1] + perp2[1], end[2] + perp2[2]],
        [end[0] - perp2[0], end[1] - perp2[1], end[2] - perp2[2]],
      ];

      for (var vert in startVerts) {
        verticesList.addAll(vert);
        normalsList.addAll([vert[0], vert[1], vert[2]]);
        uvsList.addAll([0, 0]);
      }
      for (var vert in endVerts) {
        verticesList.addAll(vert);
        normalsList.addAll([vert[0], vert[1], vert[2]]);
        uvsList.addAll([1, 0]);
      }

      for (int i = 0; i < 4; i++) {
        int next = (i + 1) % 4;
        int startCurrent = baseIndex + i;
        int startNext = baseIndex + next;
        int endCurrent = baseIndex + 4 + i;
        int endNext = baseIndex + 4 + next;

        indices.addAll([startCurrent, endCurrent, startNext]);
        indices.addAll([startNext, endCurrent, endNext]);
      }
    }

    int latitudeBands = 6;
    int longitudeBands = 6;

    List<List<double>> allSpherePoints = [];

    for (int latNumber = 0; latNumber <= latitudeBands; latNumber++) {
      double theta = latNumber * pi / latitudeBands;
      double sinTheta = sin(theta);
      double cosTheta = cos(theta);

      for (int longNumber = 0; longNumber <= longitudeBands; longNumber++) {
        double phi = longNumber * 2 * pi / longitudeBands;
        double sinPhi = sin(phi);
        double cosPhi = cos(phi);

        double x = sphereRadius * cosPhi * sinTheta;
        double y = sphereRadius * cosTheta;
        double z = sphereRadius * sinPhi * sinTheta;

        allSpherePoints.add([x, y, z]);
      }
    }

    List<double> getSpherePoint(int lat, int long) {
      int index = lat * (longitudeBands + 1) + long;
      return allSpherePoints[index];
    }

    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        addWireSegment(getSpherePoint(latNumber, longNumber),
            getSpherePoint(latNumber + 1, longNumber));
        addWireSegment(getSpherePoint(latNumber, longNumber),
            getSpherePoint(latNumber, (longNumber + 1) % longitudeBands));
      }
    }

    double nearHeight = 2.0 * frustumNear * tan(fov / 2);
    double nearWidth = nearHeight * 1.333;
    double farHeight = 2.0 * frustumFar * tan(fov / 2);
    double farWidth = farHeight * 1.333;

    List<double> sphereCenter = [0, 0, 0];
    List<List<double>> nearCorners = [
      [-nearWidth / 2, -nearHeight / 2, -frustumNear],
      [nearWidth / 2, -nearHeight / 2, -frustumNear],
      [nearWidth / 2, nearHeight / 2, -frustumNear],
      [-nearWidth / 2, nearHeight / 2, -frustumNear],
    ];

    List<List<double>> farCorners = [
      [-farWidth / 2, -farHeight / 2, -frustumFar],
      [farWidth / 2, -farHeight / 2, -frustumFar],
      [farWidth / 2, farHeight / 2, -frustumFar],
      [-farWidth / 2, farHeight / 2, -frustumFar],
    ];

    for (int i = 0; i < 4; i++) {
      addWireSegment(nearCorners[i], nearCorners[(i + 1) % 4]);
    }
    for (int i = 0; i < 4; i++) {
      addWireSegment(farCorners[i], farCorners[(i + 1) % 4]);
    }
    for (int i = 0; i < 4; i++) {
      addWireSegment(nearCorners[i], farCorners[i]);
    }
    for (int i = 0; i < 4; i++) {
      addWireSegment(sphereCenter, nearCorners[i]);
    }

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, Uint16List.fromList(indices),
        normals: _normals, uvs: _uvs, primitiveType: PrimitiveType.TRIANGLES);
  }
}
