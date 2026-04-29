import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';

class ConeGeometry {
  static Geometry conic(
      {double radius = 1.0,
      double length = 1.0,
      bool normals = true,
      bool uvs = true}) {
    int segments = 32;
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    // Create side vertices (base circle + apex)
    // Add apex vertex first
    verticesList.addAll([0, length, 0]);
    if (normals) {
      normalsList.addAll([0, 1, 0]);
    }
    if (uvs) {
      uvsList.addAll([0.5, 1]);
    }

    // Now add base circle vertices
    for (int i = 0; i <= segments; i++) {
      double theta = (i % segments) * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      // Base circle vertex
      verticesList.addAll([x, 0, z]);

      if (normals) {
        // Calculate normal for the side (perpendicular to the cone surface)
        // For a cone, the normal is perpendicular to the slant height
        // We calculate it directly without using cross product

        // Calculate the slant height vector (from base point to apex)
        double slantX = -x; // Vector from base point to apex
        double slantY = length;
        double slantZ = -z;

        // Calculate tangent vector around the circle (perpendicular to radius)
        double tangentX = -z;
        double tangentY = 0;
        double tangentZ = x;

        // Cross product of tangent and slant gives the normal
        double nx = (tangentY * slantZ) - (tangentZ * slantY);
        double ny = (tangentZ * slantX) - (tangentX * slantZ);
        double nz = (tangentX * slantY) - (tangentY * slantX);

        // Normalize
        double normalLength = sqrt(nx * nx + ny * ny + nz * nz);
        nx /= normalLength;
        ny /= normalLength;
        nz /= normalLength;

        normalsList.addAll([nx, ny, nz]);
      }

      if (uvs) {
        // UV coordinates for base edge
        uvsList.addAll([i / segments, 0]);
      }
    }

    // Create side faces indices
    // Apex is at index 0
    for (int i = 0; i < segments; i++) {
      int current = i + 1; // +1 because apex is at index 0
      int next = ((i + 1) % segments) + 1; // +1 for the same reason

      // Create triangular faces from edge to apex
      // Using counter-clockwise winding when viewed from outside
      indices.addAll([0, current, next]);
    }

    // Create base vertices separately (for proper normals)
    int baseStartIndex = verticesList.length ~/ 3;

    // Center vertex for base
    verticesList.addAll([0, 0, 0]);
    if (normals) {
      normalsList.addAll([0, -1, 0]);
    }
    if (uvs) {
      uvsList.addAll([0.5, 0.5]);
    }

    // Add base edge vertices
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

    // Create base faces indices
    for (int i = 0; i < segments; i++) {
      int current = baseStartIndex + 1 + i;
      int next = baseStartIndex + 1 + ((i + 1) % segments);

      // Using clockwise winding for base faces (since they face down)
      indices.addAll([baseStartIndex, next, current]);
    }

    // Convert to Float32List
    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, Uint16List.fromList(indices),
        normals: _normals, uvs: _uvs);
  }
}
