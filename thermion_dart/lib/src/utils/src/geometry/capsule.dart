import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';

class CapsuleGeometry {
  /// Creates a capsule geometry (cylinder with hemispherical caps).
  ///
  /// The capsule is oriented along the Y-axis and centered at the origin.
  /// [radius] controls the radius of the cylinder and hemispherical caps.
  /// [height] is the total height from bottom to top (including caps).
  /// If height <= 2*radius, the capsule becomes a sphere.
  static Geometry capsule({
    double radius = 1.0,
    double height = 2.0,
    bool normals = true,
    bool uvs = true,
  }) {
    int latitudeBands = 10;
    int longitudeBands = 16;

    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    // Calculate the height of the cylindrical section
    double cylinderHeight = max(0, height - 2 * radius);
    double halfCylinderHeight = cylinderHeight / 2;

    // Generate top hemisphere (latitude 0 to pi/2)
    // Offset upward by halfCylinderHeight
    int topHemiLatBands = latitudeBands ~/ 2;
    for (int latNumber = 0; latNumber <= topHemiLatBands; latNumber++) {
      double theta = latNumber * (pi / 2) / topHemiLatBands;
      double sinTheta = sin(theta);
      double cosTheta = cos(theta);

      for (int longNumber = 0; longNumber <= longitudeBands; longNumber++) {
        double phi = longNumber * 2 * pi / longitudeBands;
        double sinPhi = sin(phi);
        double cosPhi = cos(phi);

        double x = radius * cosPhi * sinTheta;
        double y = radius * cosTheta + halfCylinderHeight; // Offset up
        double z = radius * sinPhi * sinTheta;

        // Normal points outward from the hemisphere center
        double nx = cosPhi * sinTheta;
        double ny = cosTheta;
        double nz = sinPhi * sinTheta;

        verticesList.addAll([x, y, z]);
        normalsList.addAll([nx, ny, nz]);
        uvsList.addAll([
          longNumber / longitudeBands,
          latNumber / latitudeBands / 2,
        ]);
      }
    }

    int topHemiVertexCount = (topHemiLatBands + 1) * (longitudeBands + 1);

    // Generate bottom hemisphere (latitude pi/2 to pi)
    // Offset downward by halfCylinderHeight
    int bottomHemiLatBands = latitudeBands ~/ 2;
    for (int latNumber = 0; latNumber <= bottomHemiLatBands; latNumber++) {
      double theta = (pi / 2) + latNumber * (pi / 2) / bottomHemiLatBands;
      double sinTheta = sin(theta);
      double cosTheta = cos(theta);

      for (int longNumber = 0; longNumber <= longitudeBands; longNumber++) {
        double phi = longNumber * 2 * pi / longitudeBands;
        double sinPhi = sin(phi);
        double cosPhi = cos(phi);

        double x = radius * cosPhi * sinTheta;
        double y = radius * cosTheta - halfCylinderHeight; // Offset down
        double z = radius * sinPhi * sinTheta;

        // Normal points outward from the hemisphere center
        double nx = cosPhi * sinTheta;
        double ny = cosTheta;
        double nz = sinPhi * sinTheta;

        verticesList.addAll([x, y, z]);
        normalsList.addAll([nx, ny, nz]);
        uvsList.addAll([
          longNumber / longitudeBands,
          0.5 + (latNumber / bottomHemiLatBands / 2),
        ]);
      }
    }

    // Generate indices for top hemisphere
    for (int latNumber = 0; latNumber < topHemiLatBands; latNumber++) {
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

    // Generate indices for cylindrical section (connects top and bottom hemispheres)
    // The equator of top hemisphere connects to the equator of bottom hemisphere
    if (cylinderHeight > 0) {
      int topEquatorStart = topHemiLatBands * (longitudeBands + 1);
      int bottomEquatorStart =
          topHemiVertexCount; // First row of bottom hemisphere

      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int topCurrent = topEquatorStart + longNumber;
        int topNext = topEquatorStart + longNumber + 1;
        int bottomCurrent = bottomEquatorStart + longNumber;
        int bottomNext = bottomEquatorStart + longNumber + 1;

        indices.addAll([topCurrent, bottomCurrent, topNext]);
        indices.addAll([bottomCurrent, bottomNext, topNext]);
      }
    }

    // Generate indices for bottom hemisphere
    for (int latNumber = 0; latNumber < bottomHemiLatBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = topHemiVertexCount +
            (latNumber * (longitudeBands + 1)) +
            longNumber;
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
