import 'dart:math';
import 'dart:typed_data';

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
        
        uvsList.addAll([longNumber / longitudeBands, latNumber / latitudeBands]);
      }
    }

    for (int latNumber = 0; latNumber < latitudeBands; latNumber++) {
      for (int longNumber = 0; longNumber < longitudeBands; longNumber++) {
        int first = (latNumber * (longitudeBands + 1)) + longNumber;
        int second = first + longitudeBands + 1;

        indices.addAll([first, second, first + 1, second, second + 1, first + 1]);
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
  ]);

  final _normals = normals ? Float32List.fromList([
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
  ]) : null;

  final _uvs = uvs ? Float32List.fromList([
    // Front face
    1/3, 1/3,
    2/3, 1/3,
    2/3, 2/3,
    1/3, 2/3,

    // Back face
    2/3, 2/3,
    2/3, 1,
    1, 1,
    1, 2/3,

    // Top face
    1/3, 0,
    1/3, 1/3,
    2/3, 1/3,
    2/3, 0,

    // Bottom face
    1/3, 2/3,
    2/3, 2/3,
    2/3, 1,
    1/3, 1,

    // Right face
    2/3, 1/3,
    2/3, 2/3,
    1, 2/3,
    1, 1/3,

    // Left face
    0, 1/3,
    1/3, 1/3,
    1/3, 2/3,
    0, 2/3,
  ]) : null;

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

  static Geometry cylinder({double radius = 1.0, double length = 1.0, bool normals = true, bool uvs = true }) {
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

  static Geometry conic({double radius = 1.0, double length = 1.0, bool normals = true, bool uvs = true}) {
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

      // Base circle
      verticesList.addAll([x, 0, z]);

      // Calculate normal for the side
      double nx = x / sqrt(x * x + length * length);
      double nz = z / sqrt(z * z + length * length);
      double ny = radius / sqrt(radius * radius + length * length);
      normalsList.addAll([nx, ny, nz]);

      // UV coordinates
      uvsList.addAll([i / segments, 0]);
    }
    // Apex
    verticesList.addAll([0, length, 0]);
    normalsList.addAll([0, 1, 0]); // Normal at apex points straight up
    uvsList.addAll([0.5, 1]); // UV for apex

    // Create indices
    for (int i = 0; i < segments; i++) {
      // Base face (fixed to counterclockwise)
      indices.addAll([segments + 1, i + 1, i]);
      // Side faces (already correct)
      indices.addAll([i, segments, i + 1]);
    }

    // Add base face normals and UVs
    for (int i = 0; i <= segments; i++) {
      normalsList.addAll([0, -1, 0]); // Base face normal
      double u = 0.5 + 0.5 * cos(i * 2 * pi / segments);
      double v = 0.5 + 0.5 * sin(i * 2 * pi / segments);
      uvsList.addAll([u, v]); // Base face UV
    }

    Float32List vertices = Float32List.fromList(verticesList);
    Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
    Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry plane({double width = 1.0, double height = 1.0, bool normals = true, bool uvs = true}) {
    Float32List vertices = Float32List.fromList([
      -width / 2, 0, -height / 2,
      width / 2, 0, -height / 2,
      width / 2, 0, height / 2,
      -width / 2, 0, height / 2,
    ]);

    Float32List? _normals = normals ? Float32List.fromList([
      0, 1, 0,
      0, 1, 0,
      0, 1, 0,
      0, 1, 0,
    ]) : null;

    Float32List? _uvs = uvs ? Float32List.fromList([
      0, 0,
      1, 0,
      1, 1,
      0, 1,
    ]) : null;

    List<int> indices = [
      0, 2, 1,
      0, 3, 2,
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
  int latitudeBands = 6;  // Reduced bands for simpler wireframe
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
      normalsList.addAll([x / sphereRadius, y / sphereRadius, z / sphereRadius]);
      uvsList.addAll([longNumber / longitudeBands, latNumber / latitudeBands]);
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
  verticesList.addAll([0, 0, 0]);  // Sphere center at origin
  normalsList.addAll([0, 0, -1]);  // Backward-facing normal
  uvsList.addAll([0.5, 0.5]);      // Center UV coordinate
  
  // Calculate frustum corners
  double nearHeight = 2.0 * frustumNear * tan(fov / 2);
  double nearWidth = nearHeight * 1.333;  // Assuming 4:3 aspect ratio
  double farHeight = 2.0 * frustumFar * tan(fov / 2);
  double farWidth = farHeight * 1.333;
  
  // Store starting index for frustum vertices
  int nearBaseIndex = verticesList.length ~/ 3;
  
  // Add near rectangle vertices (negative z)
  verticesList.addAll([
    -nearWidth/2, -nearHeight/2, -frustumNear,  // Bottom-left
    nearWidth/2, -nearHeight/2, -frustumNear,   // Bottom-right
    nearWidth/2, nearHeight/2, -frustumNear,    // Top-right
    -nearWidth/2, nearHeight/2, -frustumNear,   // Top-left
  ]);
  
  // Add far rectangle vertices (negative z)
  int farBaseIndex = verticesList.length ~/ 3;
  verticesList.addAll([
    -farWidth/2, -farHeight/2, -frustumFar,     // Bottom-left
    farWidth/2, -farHeight/2, -frustumFar,      // Bottom-right
    farWidth/2, farHeight/2, -frustumFar,       // Top-right
    -farWidth/2, farHeight/2, -frustumFar,      // Top-left
  ]);
  
  // Add normals and UVs for frustum vertices
  for (int i = 0; i < 8; i++) {
    normalsList.addAll([0, 0, -1]);  // Backward-facing normal
    uvsList.addAll([0, 0]);
  }
  
  // Add line indices for near rectangle
  indices.addAll([
    nearBaseIndex, nearBaseIndex + 1,     // Bottom
    nearBaseIndex + 1, nearBaseIndex + 2, // Right
    nearBaseIndex + 2, nearBaseIndex + 3, // Top
    nearBaseIndex + 3, nearBaseIndex      // Left
  ]);
  
  // Add line indices for far rectangle
  indices.addAll([
    farBaseIndex, farBaseIndex + 1,     // Bottom
    farBaseIndex + 1, farBaseIndex + 2, // Right
    farBaseIndex + 2, farBaseIndex + 3, // Top
    farBaseIndex + 3, farBaseIndex      // Left
  ]);
  
  // Add lines connecting near and far rectangles
  indices.addAll([
    nearBaseIndex, farBaseIndex,         // Bottom-left
    nearBaseIndex + 1, farBaseIndex + 1, // Bottom-right
    nearBaseIndex + 2, farBaseIndex + 2, // Top-right
    nearBaseIndex + 3, farBaseIndex + 3  // Top-left
  ]);
  
  // Add lines from sphere center to near corners
  indices.addAll([
    sphereCenterIndex, nearBaseIndex,     // To near bottom-left
    sphereCenterIndex, nearBaseIndex + 1, // To near bottom-right
    sphereCenterIndex, nearBaseIndex + 2, // To near top-right
    sphereCenterIndex, nearBaseIndex + 3  // To near top-left
  ]);
  
  Float32List vertices = Float32List.fromList(verticesList);
  Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
  Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;
  
  return Geometry(
    vertices, 
    indices, 
    normals: _normals, 
    uvs: _uvs,
    primitiveType: PrimitiveType.LINES
  );
}

static Geometry wireframeCameraContainer({
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

  // Calculate frustum corners
  double nearHeight = 2.0 * frustumNear * tan(fov / 2);
  double nearWidth = nearHeight * 1.333;  // 4:3 aspect ratio
  double farHeight = 2.0 * frustumFar * tan(fov / 2);
  double farWidth = farHeight * 1.333;

  // Add padding to fully encompass the camera
  double padding = sphereRadius * 0.5;
  
  // Calculate container dimensions to encompass both sphere and frustum
  double containerWidth = max(farWidth, sphereRadius * 2) + padding * 2;
  double containerHeight = max(farHeight, sphereRadius * 2) + padding * 2;
  double containerDepth = frustumFar + sphereRadius + padding * 2;
  
  // Center offset to position container around camera
  double offsetZ = (frustumFar - sphereRadius) / 2;

  // Define container vertices
  List<List<double>> containerPoints = [
    // Front face
    [-containerWidth/2, -containerHeight/2, -sphereRadius - padding + offsetZ],
    [containerWidth/2, -containerHeight/2, -sphereRadius - padding + offsetZ],
    [containerWidth/2, containerHeight/2, -sphereRadius - padding + offsetZ],
    [-containerWidth/2, containerHeight/2, -sphereRadius - padding + offsetZ],
    // Back face
    [-containerWidth/2, -containerHeight/2, frustumFar + padding + offsetZ],
    [containerWidth/2, -containerHeight/2, frustumFar + padding + offsetZ],
    [containerWidth/2, containerHeight/2, frustumFar + padding + offsetZ],
    [-containerWidth/2, containerHeight/2, frustumFar + padding + offsetZ],
  ];

  // Add vertices
  for (var point in containerPoints) {
    verticesList.addAll(point);
    normalsList.addAll([0, 0, 1]); // Simplified normals
    uvsList.addAll([0, 0]); // Basic UVs
  }

  // Define triangles for faces (12 triangles = 6 faces)
  var triangleIndices = [
    // Front face
    0, 1, 2, 0, 2, 3,
    // Back face
    4, 6, 5, 4, 7, 6,
    // Top face
    3, 2, 6, 3, 6, 7,
    // Bottom face
    0, 5, 1, 0, 4, 5,
    // Left face
    0, 3, 7, 0, 7, 4,
    // Right face
    1, 5, 6, 1, 6, 2
  ];
  
  indices.addAll(triangleIndices);

  Float32List vertices = Float32List.fromList(verticesList);
  Float32List? _normals = normals ? Float32List.fromList(normalsList) : null;
  Float32List? _uvs = uvs ? Float32List.fromList(uvsList) : null;
  
  return Geometry(
    vertices,
    indices,
    normals: _normals,
    uvs: _uvs,
    primitiveType: PrimitiveType.TRIANGLES
  );
}
}