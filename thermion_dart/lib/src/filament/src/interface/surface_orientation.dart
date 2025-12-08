import 'dart:typed_data';
import 'package:thermion_dart/thermion_dart.dart';

/// Output format for tangent space quaternions.
enum QuaternionFormat {
  /// 32-bit float components (4 floats = 16 bytes per quaternion)
  FLOAT4,

  /// 16-bit signed integer components (4 shorts = 8 bytes per quaternion)
  SHORT4,

  /// 16-bit half-float components (4 halfs = 8 bytes per quaternion)
  HALF4,
}

/// Helper class for generating Filament-style tangent space quaternions.
///
/// The surface orientation helper can be used to populate TANGENTS buffers
/// with quaternion representations of tangent space. This is more efficient
/// than storing separate tangent, bitangent, and normal vectors.
///
/// Usage example:
/// ```dart
/// final builder = SurfaceOrientationBuilder()
///   ..vertexCount(vertexPositions.length)
///   ..positions(vertexPositions)
///   ..normals(vertexNormals)
///   ..uvs(vertexUVs)
///   ..triangles(triangleIndices);
///
/// final orientation = await builder.build();
///
/// // Get quaternions as float4
/// final quats = await orientation.getQuats(
///   QuaternionFormat.FLOAT4,
///   vertexCount
/// );
/// ```
abstract class SurfaceOrientation {
  /// Returns the number of vertices for this surface orientation.
  int getVertexCount();

  /// Retrieves the tangent space quaternions in the specified format.
  ///
  /// [format] The output format for the quaternions
  /// [quatCount] Number of quaternions to retrieve (usually equal to vertex count)
  /// [stride] Byte stride between quaternions (default 0 = tightly packed)
  ///
  /// Returns a TypedData containing the quaternion data in the requested format.
  Future<TypedData> getQuats(
    QuaternionFormat format,
    int quatCount, {
    int stride = 0,
  });

  /// Destroys this surface orientation and releases associated resources.
  Future<void> destroy();
}

/// Builder for creating SurfaceOrientation instances.
///
/// The builder allows you to configure the input data needed to generate
/// tangent space quaternions. At a minimum, you must provide the vertex count.
/// You can supply data in various combinations:
///
/// 1. Normals only - Not recommended, selects arbitrary orientation
/// 2. Normals + tangents - Sign of W determines bitangent orientation
/// 3. Normals + UVs + positions + indices - Uses Lengyel's Method (recommended)
/// 4. Positions + indices - Generates normals for flat shading only
abstract class SurfaceOrientationBuilder {
  /// Sets the vertex count.
  ///
  /// This is required and must be called before building.
  void vertexCount(int count);

  /// Sets the vertex normal data.
  ///
  /// [normals] Float3 normal data (XYZ components)
  /// [stride] Byte stride between normals (default 0 = tightly packed)
  void normals(Float32List normals, {int stride = 0});

  /// Sets the vertex tangent data.
  ///
  /// [tangents] Float4 tangent data (XYZW components, where W determines handedness)
  /// [stride] Byte stride between tangents (default 0 = tightly packed)
  void tangents(Float32List tangents, {int stride = 0});

  /// Sets the vertex UV texture coordinates.
  ///
  /// [uvs] Float2 UV data (U,V coordinates)
  /// [stride] Byte stride between UVs (default 0 = tightly packed)
  void uvs(Float32List uvs, {int stride = 0});

  /// Sets the vertex position data.
  ///
  /// [positions] Float3 position data (XYZ coordinates)
  /// [stride] Byte stride between positions (default 0 = tightly packed)
  void positions(Float32List positions, {int stride = 0});

  /// Sets the triangle count.
  ///
  /// Required if providing triangle indices.
  void triangleCount(int count);

  /// Sets the triangle indices using 32-bit unsigned integers.
  ///
  /// Each triangle is defined by 3 vertex indices.
  /// [triangles] Uint32List of triangle indices (3 indices per triangle)
  void trianglesUint32(Uint32List triangles);

  /// Sets the triangle indices using 16-bit unsigned integers.
  ///
  /// Each triangle is defined by 3 vertex indices.
  /// [triangles] Uint16List of triangle indices (3 indices per triangle)
  void trianglesUint16(Uint16List triangles);

  /// Builds the SurfaceOrientation object.
  ///
  /// After building, the orientation can be used to generate tangent space
  /// quaternions for use in vertex buffer TANGENTS attributes.
  ///
  /// Returns the newly created SurfaceOrientation instance.
  Future<SurfaceOrientation> build();
}