import 'dart:math';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../../thermion_dart.dart';

class GeometryHelper {
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

        uvsList
            .addAll([longNumber / longitudeBands, latNumber / latitudeBands]);
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

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry cube({bool normals = true, bool uvs = true}) {
    final vertices = Float32List.fromList([
      // Front face
      -1, -1, 1, // 0
      1, -1, 1, // 1
      1, 1, 1, // 2
      -1, 1, 1, // 3

      // Back face
      -1, -1, -1, // 4
      1, -1, -1, // 5
      1, 1, -1, // 6
      -1, 1, -1, // 7

      // Top face
      -1, 1, 1, // 3 (8)
      1, 1, 1, //2 (9)
      1, 1, -1, //6 (10)
      -1, 1, -1, // 7 (11)

      // Bottom
      -1, -1, -1, // 4 (12)
      1, -1, -1, // 5 (13)
      1, -1, 1, // 1 (14)
      -1, -1, 1, // 0 (15)

      // Right
      1, -1, 1, // 1 (16)
      1, -1, -1, // 5 (17)
      1, 1, -1, // 6 (18)
      1, 1, 1, // 2 (19)

      // Left
      -1, -1, -1, // 4 (20)
      -1, -1, 1, // 0 (21)
      -1, 1, 1, // 3 (22)
      -1, 1, -1 // 7 (23)
    ]);

    final _normals = normals
        ? Float32List.fromList([
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
            0,
            1,
            0,
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
            -1,
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
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
            -1,
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
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
            -1,
            0,
            0,
          ])
        : null;

    final _uvs = uvs
        ? Float32List.fromList([
            // front
            1 / 3, 3 / 4, // 0
            2 / 3, 3 / 4, // 1
            2 / 3, 1, // 2
            1 / 3, 1, // 3

            // back
            1 / 3, 1 / 4, // 4
            2 / 3, 1 / 4, // 5
            2 / 3, 1 / 2, // 6
            1 / 3, 1 / 2, // 7

            // top
            2 / 3, 1 / 2, // 8
            1, 1 / 2, // 9
            1, 3 / 4, // 10
            2 / 3, 3 / 4, // 11

            // bottom
            0, 1 / 2, // 12
            1 / 3, 1 / 2, // 13
            1 / 3, 3 / 4, // 14
            0, 3 / 4, // 15

            // right
            1 / 3, 1 / 2, // 16
            2 / 3, 1 / 2, // 17
            2 / 3, 3 / 4, // 18
            1 / 3, 3 / 4, // 19

            // left
            1 / 3, 0, // 20
            2 / 3, 0, // 21
            2 / 3, 1 / 4, // 22
            1 / 3, 1 / 4 // 23
          ])
        : null;

    final indices = [
      // Front face
      0, 1, 2, 0, 2, 3,
      // Back face
      5, 4, 7, 5, 7, 6,
      // Top face
      8, 9, 10, 8, 10, 11, // 3,2,6,3,6,7, //
      // Bottom face
      12, 13, 14, 12, 14, 15, // 4,5,1,4,1,0,
      // Right face
      16, 17, 18, 16, 18, 19, //1,5,6,1,6,2,
      // Left face
      20, 21, 22, 20, 22, 23 // 4,0,3,4,3,7
    ];
    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry cylinder(
      {double radius = 1.0,
      double length = 1.0,
      bool normals = true,
      bool uvs = true}) {
    int segments = 32;
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    // Create vertices, normals, and UVs
    for (int i = 0; i <= segments; i++) {
      double theta = i * 2 * pi / segments;
      double x = radius * cos(theta);
      double z = radius * sin(theta);

      // Top circle
      verticesList.addAll([x, length / 2, z]);
      normalsList.addAll([x / radius, 0, z / radius]);
      uvsList.addAll([i / segments, 1]);

      // Bottom circle
      verticesList.addAll([x, -length / 2, z]);
      normalsList.addAll([x / radius, 0, z / radius]);
      uvsList.addAll([i / segments, 0]);
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

    // Add center vertices, normals, and UVs for top and bottom faces
    verticesList.addAll([0, length / 2, 0]); // Top center
    normalsList.addAll([0, 1, 0]);
    uvsList.addAll([0.5, 0.5]); // Center of top face

    verticesList.addAll([0, -length / 2, 0]); // Bottom center
    normalsList.addAll([0, -1, 0]);
    uvsList.addAll([0.5, 0.5]); // Center of bottom face

    // Add top and bottom face normals and UVs
    for (int i = 0; i <= segments; i++) {
      normalsList.addAll([0, 1, 0]); // Top face normal
      normalsList.addAll([0, -1, 0]); // Bottom face normal

      double u = 0.5 + 0.5 * cos(i * 2 * pi / segments);
      double v = 0.5 + 0.5 * sin(i * 2 * pi / segments);
      uvsList.addAll([u, v]); // Top face UV
      uvsList.addAll([u, v]); // Bottom face UV
    }

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

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

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry plane(
      {double width = 1.0,
      double height = 1.0,
      bool normals = true,
      bool uvs = true}) {
    Float32List vertices = Float32List.fromList([
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
    ]);

    Float32List? _normals = normals
        ? Float32List.fromList([
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
          ])
        : null;

    Float32List? _uvs =
        uvs ? Float32List.fromList([
          0, 0,
          1, 0,
          1, 1,
          0, 1,
          ]) : null;

    List<int> indices = [
      0,
      1,
      2,
      0,
      2,
      3,
    ];

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry wireframeCamera({
    double sphereRadius = 0.2,
    double frustumDistance = 1.0,
    double frustumNear = 0.5,
    double frustumFar = 1.0,
    double fov = pi / 3,
    bool normals = true,
    bool uvs = true,
  }) {
    List<double> verticesList = [];
    List<double> normalsList = [];
    List<double> uvsList = [];
    List<int> indices = [];

    // Create sphere vertices - keeping bands low for wireframe and to stay within Uint16 limits
    int latitudeBands = 6; // Reduced bands for simpler wireframe
    int longitudeBands = 6;

    // Generate sphere vertices
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

        verticesList.addAll([x, y, z]);
        normalsList
            .addAll([x / sphereRadius, y / sphereRadius, z / sphereRadius]);
        uvsList
            .addAll([longNumber / longitudeBands, latNumber / latitudeBands]);
      }
    }

    // Generate sphere line indices
    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = (latNumber * (longitudeBands + 1)) + longNumber;
        int second = first + longitudeBands + 1;
        int third = first + 1;

        // Add vertical lines
        indices.addAll([first, second]);

        // Add horizontal lines
        if (longNumber < longitudeBands - 1) {
          indices.addAll([first, third]);
        } else {
          // Connect back to first vertex of this latitude
          indices.addAll([first, latNumber * (longitudeBands + 1)]);
        }
      }
    }

    // Add center point of sphere for frustum lines
    int sphereCenterIndex = verticesList.length ~/ 3;
    verticesList.addAll([0, 0, 0]); // Sphere center at origin
    normalsList.addAll([0, 0, -1]); // Backward-facing normal
    uvsList.addAll([0.5, 0.5]); // Center UV coordinate

    // Calculate frustum corners
    double nearHeight = 2.0 * frustumNear * tan(fov / 2);
    double nearWidth = nearHeight * 1.333; // Assuming 4:3 aspect ratio
    double farHeight = 2.0 * frustumFar * tan(fov / 2);
    double farWidth = farHeight * 1.333;

    // Store starting index for frustum vertices
    int nearBaseIndex = verticesList.length ~/ 3;

    // Add near rectangle vertices (negative z)
    verticesList.addAll([
      -nearWidth / 2, -nearHeight / 2, -frustumNear, // Bottom-left
      nearWidth / 2, -nearHeight / 2, -frustumNear, // Bottom-right
      nearWidth / 2, nearHeight / 2, -frustumNear, // Top-right
      -nearWidth / 2, nearHeight / 2, -frustumNear, // Top-left
    ]);

    // Add far rectangle vertices (negative z)
    int farBaseIndex = verticesList.length ~/ 3;
    verticesList.addAll([
      -farWidth / 2, -farHeight / 2, -frustumFar, // Bottom-left
      farWidth / 2, -farHeight / 2, -frustumFar, // Bottom-right
      farWidth / 2, farHeight / 2, -frustumFar, // Top-right
      -farWidth / 2, farHeight / 2, -frustumFar, // Top-left
    ]);

    // Add normals and UVs for frustum vertices
    for (int i = 0; i < 8; i++) {
      normalsList.addAll([0, 0, -1]); // Backward-facing normal
      uvsList.addAll([0, 0]);
    }

    // Add line indices for near rectangle
    indices.addAll([
      nearBaseIndex, nearBaseIndex + 1, // Bottom
      nearBaseIndex + 1, nearBaseIndex + 2, // Right
      nearBaseIndex + 2, nearBaseIndex + 3, // Top
      nearBaseIndex + 3, nearBaseIndex // Left
    ]);

    // Add line indices for far rectangle
    indices.addAll([
      farBaseIndex, farBaseIndex + 1, // Bottom
      farBaseIndex + 1, farBaseIndex + 2, // Right
      farBaseIndex + 2, farBaseIndex + 3, // Top
      farBaseIndex + 3, farBaseIndex // Left
    ]);

    // Add lines connecting near and far rectangles
    indices.addAll([
      nearBaseIndex, farBaseIndex, // Bottom-left
      nearBaseIndex + 1, farBaseIndex + 1, // Bottom-right
      nearBaseIndex + 2, farBaseIndex + 2, // Top-right
      nearBaseIndex + 3, farBaseIndex + 3 // Top-left
    ]);

    // Add lines from sphere center to near corners
    indices.addAll([
      sphereCenterIndex, nearBaseIndex, // To near bottom-left
      sphereCenterIndex, nearBaseIndex + 1, // To near bottom-right
      sphereCenterIndex, nearBaseIndex + 2, // To near top-right
      sphereCenterIndex, nearBaseIndex + 3 // To near top-left
    ]);

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, indices,
        normals: _normals, uvs: _uvs, primitiveType: PrimitiveType.LINES);
  }

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

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry halfPyramid(
      {double startX = 0.25,
      double startY = 0.25,
      double width = 1.0,
      double height = 1.0,
      double depth = 1.0,
      bool normals = true,
      bool uvs = true}) {
    // Define vertices for a half pyramid (triangular prism)
    // Starting at (startX, startY, 0)
    Float32List vertices = Float32List.fromList([
      // Base rectangle (bottom face)
      startX, startY, 0, // 0: front-left
      startX + width, startY, 0, // 1: front-right
      startX + width, startY + height, 0, // 2: back-right
      startX, startY + height, 0, // 3: back-left

      // Top ridge
      startX, startY + height, depth, // 4: top ridge start
      startX + width, startY + height, depth, // 5: top ridge end
    ]);

    // Define normals if needed
    Float32List? _normals = normals
        ? Float32List.fromList([
            // Base rectangle
            0, 0, -1, // Bottom face
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,

            // Ridge normals (approximate)
            0, 0.7071, 0.7071, // Angled toward ridge
            0, 0.7071, 0.7071,
          ])
        : null;

    // Define UVs if needed
    Float32List? _uvs = uvs
        ? Float32List.fromList([
            // Base rectangle UVs
            0, 0, // Bottom-left
            1, 0, // Bottom-right
            1, 1, // Top-right
            0, 1, // Top-left

            // Ridge UVs
            0, 0.5,
            1, 0.5,
          ])
        : null;

    // Define indices for triangular faces
    List<int> indices = [
      // Bottom face (rectangle)
      0, 1, 2,
      0, 2, 3,

      // Front triangular face
      0, 1, 5,
      0, 5, 4,

      // Left rectangular face
      0, 4, 3,

      // Right rectangular face
      1, 2, 5,

      // Back rectangular face
      2, 3, 4,
      2, 4, 5,
    ];

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }
}
