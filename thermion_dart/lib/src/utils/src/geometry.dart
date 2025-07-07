import 'dart:math' ;

import '../../../thermion_dart.dart';

class GeometryHelper {
  static Geometry fullscreenQuad() {
    final vertices = Float32List.fromList([-1.0, -1.0, 1.0, 3.0, -1.0, 1.0, -1.0, 3.0, 1.0]);
    final indices = Uint16List.fromList([0, 1, 2]);
    return Geometry(vertices, indices);
  }

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

    return Geometry(vertices, Uint16List.fromList(indices), normals: _normals, uvs: _uvs);
  }

  static Geometry cube(
      {bool normals = true, bool uvs = true, bool flipUvs = true}) {
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

    // Original UV coordinates
    var originalUvs = <double>[
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
    ];

    // Apply UV flipping if requested
    final _uvs = uvs
        ? Float32List.fromList(
            flipUvs ? _flipUvCoordinates(originalUvs) : originalUvs)
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

    return Geometry(vertices, Uint16List.fromList(indices), normals: _normals, uvs: _uvs);
  }

// Helper function to flip the Y coordinate of UV coordinates (y = 1.0 - y)
  static List<double> _flipUvCoordinates(List<double> uvs) {
    var flippedUvs = List<double>.from(uvs);
    for (var i = 1; i < flippedUvs.length; i += 2) {
      flippedUvs[i] = 1.0 - flippedUvs[i];
    }
    return flippedUvs;
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

    return Geometry(vertices, Uint16List.fromList(indices), normals: _normals, uvs: _uvs);
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

    return Geometry(vertices, Uint16List.fromList(indices), normals: _normals, uvs: _uvs);
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

    Float32List? _uvs = uvs
        ? Float32List.fromList([
            0,
            0,
            1,
            0,
            1,
            1,
            0,
            1,
          ])
        : null;

    final indices = Uint16List.fromList([
      0,
      1,
      2,
      0,
      2,
      3,
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }
static Geometry camera({
  double bodyWidth = 0.6,    // X-axis (medium width)
  double bodyHeight = 0.7,   // Y-axis (medium height)  
  double bodyDepth = 1.4,    // Z-axis (LONG dimension - camera body extends back)
  double lensRadius = 0.3,
  double lensLength = 0.4,
  bool normals = true,
  bool uvs = true,
}) {
  List<double> verticesList = [];
  List<double> normalsList = [];
  List<double> uvsList = [];
  List<int> indices = [];

  // Helper function to add a vertex with normal and UV
  void addVertex(double x, double y, double z, double nx, double ny, double nz, double u, double v) {
    verticesList.addAll([x, y, z]);
    if (normals) normalsList.addAll([nx, ny, nz]);
    if (uvs) uvsList.addAll([u, v]);
  }

  int currentIndex = 0;

  // === CAMERA BODY (Rectangular box) ===
  // Now: width=1.0, height=0.6, depth=1.4 (long)
  // The front face (Z=+halfDepth) is the short face where lens attaches
  double halfWidth = bodyWidth / 2;   // 0.5 (medium)
  double halfHeight = bodyHeight / 2; // 0.3 (short)
  double halfDepth = bodyDepth / 2;   // 0.7 (long - extends backward)

  // Front face (SHORT face - where lens attaches) - Z = +halfDepth
  addVertex(-halfWidth, -halfHeight, halfDepth, 0, 0, 1, 0, 0);  // 0
  addVertex(halfWidth, -halfHeight, halfDepth, 0, 0, 1, 1, 0);   // 1
  addVertex(halfWidth, halfHeight, halfDepth, 0, 0, 1, 1, 1);    // 2
  addVertex(-halfWidth, halfHeight, halfDepth, 0, 0, 1, 0, 1);   // 3

  // Back face (SHORT face) - Z = -halfDepth
  addVertex(halfWidth, -halfHeight, -halfDepth, 0, 0, -1, 0, 0); // 4
  addVertex(-halfWidth, -halfHeight, -halfDepth, 0, 0, -1, 1, 0); // 5
  addVertex(-halfWidth, halfHeight, -halfDepth, 0, 0, -1, 1, 1); // 6
  addVertex(halfWidth, halfHeight, -halfDepth, 0, 0, -1, 0, 1);  // 7

  // Top face (LONG face) - Y = +halfHeight
  addVertex(-halfWidth, halfHeight, halfDepth, 0, 1, 0, 0, 0);   // 8
  addVertex(halfWidth, halfHeight, halfDepth, 0, 1, 0, 1, 0);    // 9
  addVertex(halfWidth, halfHeight, -halfDepth, 0, 1, 0, 1, 1);   // 10
  addVertex(-halfWidth, halfHeight, -halfDepth, 0, 1, 0, 0, 1);  // 11

  // Bottom face (LONG face) - Y = -halfHeight
  addVertex(-halfWidth, -halfHeight, -halfDepth, 0, -1, 0, 0, 0); // 12
  addVertex(halfWidth, -halfHeight, -halfDepth, 0, -1, 0, 1, 0);  // 13
  addVertex(halfWidth, -halfHeight, halfDepth, 0, -1, 0, 1, 1);   // 14
  addVertex(-halfWidth, -halfHeight, halfDepth, 0, -1, 0, 0, 1);  // 15

  // Right face (LONG face) - X = +halfWidth
  addVertex(halfWidth, -halfHeight, halfDepth, 1, 0, 0, 0, 0);   // 16
  addVertex(halfWidth, -halfHeight, -halfDepth, 1, 0, 0, 1, 0);  // 17
  addVertex(halfWidth, halfHeight, -halfDepth, 1, 0, 0, 1, 1);   // 18
  addVertex(halfWidth, halfHeight, halfDepth, 1, 0, 0, 0, 1);    // 19

  // Left face (LONG face) - X = -halfWidth
  addVertex(-halfWidth, -halfHeight, -halfDepth, -1, 0, 0, 0, 0); // 20
  addVertex(-halfWidth, -halfHeight, halfDepth, -1, 0, 0, 1, 0);  // 21
  addVertex(-halfWidth, halfHeight, halfDepth, -1, 0, 0, 1, 1);   // 22
  addVertex(-halfWidth, halfHeight, -halfDepth, -1, 0, 0, 0, 1);  // 23

  // Body indices
  List<int> bodyIndices = [
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
  
  indices.addAll(bodyIndices);
  currentIndex = 24;

  // === CONICAL LENS ===
  int segments = 16;
  double lensApexZ = -halfDepth;  // Apex touches the front face (short face)
  double lensBaseZ = -halfDepth - lensLength;  // Base extends outward along Z-axis

  // Lens apex (tip of the cone - touching the camera body at center of front face)
  addVertex(0, 0, lensApexZ, 0, 0, -1, 0.5, 0);
  int apexIndex = currentIndex;
  currentIndex++;

  // Lens base circle (the wide part extending outward)
  List<int> baseIndices = [];
  for (int i = 0; i < segments; i++) {
    double theta = i * 2 * pi / segments;
    double x = lensRadius * cos(theta);
    double y = lensRadius * sin(theta);

    // Calculate normal for cone side (pointing outward from cone surface)
    double normalX = x / lensRadius;  // Normalized radial component
    double normalY = y / lensRadius;
    double normalZ = lensRadius / lensLength;  // Axial component based on cone slope
    
    // Normalize the normal vector
    double normalLength = sqrt(normalX * normalX + normalY * normalY + normalZ * normalZ);
    normalX /= normalLength;
    normalY /= normalLength;
    normalZ /= normalLength;

    addVertex(x, y, lensBaseZ, normalX, normalY, normalZ, i / segments, 1);
    baseIndices.add(currentIndex);
    currentIndex++;
  }

  // Create cone side triangles
  for (int i = 0; i < segments; i++) {
    int current = baseIndices[i];
    int next = baseIndices[(i + 1) % segments];
    
    // Triangle from apex to base edge (counter-clockwise when viewed from outside)
    indices.addAll([apexIndex, next, current]);
  }

  // === LENS BASE (flat circular face at the wide end) ===
  // Center of lens base
  addVertex(0, 0, lensBaseZ, 0, 0, 1, 0.5, 0.5);
  int baseCenterIndex = currentIndex;
  currentIndex++;

  // Base circle vertices (separate from cone vertices for proper normals)
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

  // Create base face triangles (facing outward from camera)
  for (int i = 0; i < segments; i++) {
    int current = baseFaceIndices[i];
    int next = baseFaceIndices[(i + 1) % segments];
    
    // Triangle from center to edge (counter-clockwise when viewed from outside)
    indices.addAll([baseCenterIndex, current, next]);
  }

  Float32List vertices = Float32List.fromList(verticesList);
  Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
  Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

  return Geometry(vertices, Uint16List.fromList(indices), normals: _normals, uvs: _uvs);
}

static Geometry wireframeCamera({
  double sphereRadius = 0.2,
  double frustumDistance = 1.0,
  double frustumNear = 0.5,
  double frustumFar = 1.0,
  double fov = pi / 3,
  bool normals = true,
  bool uvs = true,
  double wireThickness = 0.01, // Thickness of the wireframe edges
}) {
  List<double> verticesList = [];
  List<double> normalsList = [];
  List<double> uvsList = [];
  List<int> indices = [];

  // Helper function to create a thin triangular tube between two points
  void addWireSegment(List<double> start, List<double> end) {
    int baseIndex = verticesList.length ~/ 3;
    
    // Calculate direction vector
    double dx = end[0] - start[0];
    double dy = end[1] - start[1];
    double dz = end[2] - start[2];
    double length = sqrt(dx * dx + dy * dy + dz * dz);
    
    // Create perpendicular vectors for thickness
    List<double> perp1, perp2;
    if (dx.abs() < 0.9) {
      perp1 = [0, -dz, dy];
    } else {
      perp1 = [-dy, dx, 0];
    }
    
    // Normalize perpendicular vector
    double perpLength = sqrt(perp1[0] * perp1[0] + perp1[1] * perp1[1] + perp1[2] * perp1[2]);
    if (perpLength > 0) {
      perp1 = [perp1[0] / perpLength * wireThickness, 
               perp1[1] / perpLength * wireThickness, 
               perp1[2] / perpLength * wireThickness];
    }
    
    // Second perpendicular (cross product)
    perp2 = [dy * perp1[2] - dz * perp1[1],
             dz * perp1[0] - dx * perp1[2],
             dx * perp1[1] - dy * perp1[0]];
    
    // Create 4 vertices around each end point (rectangular cross-section)
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
    
    // Add vertices
    for (var vert in startVerts) {
      verticesList.addAll(vert);
      normalsList.addAll([vert[0], vert[1], vert[2]]); // Simple normal
      uvsList.addAll([0, 0]);
    }
    for (var vert in endVerts) {
      verticesList.addAll(vert);
      normalsList.addAll([vert[0], vert[1], vert[2]]); // Simple normal
      uvsList.addAll([1, 0]);
    }
    
    // Create triangular faces for the tube (4 sides, 2 triangles each)
    for (int i = 0; i < 4; i++) {
      int next = (i + 1) % 4;
      int startCurrent = baseIndex + i;
      int startNext = baseIndex + next;
      int endCurrent = baseIndex + 4 + i;
      int endNext = baseIndex + 4 + next;
      
      // Two triangles per side
      indices.addAll([startCurrent, endCurrent, startNext]);
      indices.addAll([startNext, endCurrent, endNext]);
    }
  }

  // Create sphere wireframe edges
  int latitudeBands = 6;
  int longitudeBands = 6;
  
  // Store sphere points as a flat list for easier access
  List<List<double>> allSpherePoints = [];
  
  // Generate sphere vertices and store them
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

  // Helper function to get sphere point by lat/long indices
  List<double> getSpherePoint(int lat, int long) {
    int index = lat * (longitudeBands + 1) + long;
    return allSpherePoints[index];
  }

  // Add sphere wireframe edges
  for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
    for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
      // Vertical lines
      addWireSegment(getSpherePoint(latNumber, longNumber), 
                    getSpherePoint(latNumber + 1, longNumber));
      
      // Horizontal lines
      addWireSegment(getSpherePoint(latNumber, longNumber), 
                    getSpherePoint(latNumber, (longNumber + 1) % longitudeBands));
    }
  }

  // Calculate frustum corners
  double nearHeight = 2.0 * frustumNear * tan(fov / 2);
  double nearWidth = nearHeight * 1.333;
  double farHeight = 2.0 * frustumFar * tan(fov / 2);
  double farWidth = farHeight * 1.333;

  // Frustum corner points
  List<double> sphereCenter = [0, 0, 0];
  List<List<double>> nearCorners = [
    [-nearWidth / 2, -nearHeight / 2, -frustumNear], // Bottom-left
    [nearWidth / 2, -nearHeight / 2, -frustumNear],  // Bottom-right
    [nearWidth / 2, nearHeight / 2, -frustumNear],   // Top-right
    [-nearWidth / 2, nearHeight / 2, -frustumNear],  // Top-left
  ];

  List<List<double>> farCorners = [
    [-farWidth / 2, -farHeight / 2, -frustumFar], // Bottom-left
    [farWidth / 2, -farHeight / 2, -frustumFar],  // Bottom-right
    [farWidth / 2, farHeight / 2, -frustumFar],   // Top-right
    [-farWidth / 2, farHeight / 2, -frustumFar],  // Top-left
  ];

  // Add frustum wireframe edges
  
  // Near rectangle edges
  for (int i = 0; i < 4; i++) {
    addWireSegment(nearCorners[i], nearCorners[(i + 1) % 4]);
  }

  // Far rectangle edges
  for (int i = 0; i < 4; i++) {
    addWireSegment(farCorners[i], farCorners[(i + 1) % 4]);
  }

  // Connecting edges between near and far
  for (int i = 0; i < 4; i++) {
    addWireSegment(nearCorners[i], farCorners[i]);
  }

  // Lines from sphere center to near corners
  for (int i = 0; i < 4; i++) {
    addWireSegment(sphereCenter, nearCorners[i]);
  }

  Float32List vertices = Float32List.fromList(verticesList);
  Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
  Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

  return Geometry(vertices, Uint16List.fromList(indices),
      normals: _normals, uvs: _uvs, primitiveType: PrimitiveType.TRIANGLES);
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
    Uint16List indices = Uint16List.fromList([
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
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }
}
