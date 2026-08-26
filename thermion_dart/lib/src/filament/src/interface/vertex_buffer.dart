import 'package:thermion_dart/thermion_dart.dart';

/// Vertex attribute types that can be stored in a VertexBuffer.
///
/// Each attribute has a specific semantic meaning and type requirement.
enum VertexAttribute {
  /// XYZ position (float3)
  POSITION,

  /// Tangent, bitangent and normal, encoded as a quaternion (float4)
  TANGENTS,

  /// Vertex color (float4)
  COLOR,

  /// Texture coordinates (float2)
  UV0,

  /// Texture coordinates (float2)
  UV1,

  /// Indices of 4 bones, as unsigned integers (uvec4)
  BONE_INDICES,

  /// Weights of the 4 bones (normalized float4)
  BONE_WEIGHTS,

  /// Custom attribute 0
  CUSTOM0,

  /// Custom attribute 1
  CUSTOM1,

  /// Custom attribute 2
  CUSTOM2,

  /// Custom attribute 3
  CUSTOM3,

  /// Custom attribute 4
  CUSTOM4,

  /// Custom attribute 5
  CUSTOM5,

  /// Custom attribute 6
  CUSTOM6,

  /// Custom attribute 7
  CUSTOM7,
}

/// Type of data stored in a vertex attribute.
///
/// These correspond to shader data types and determine how the GPU
/// interprets the raw buffer data. All variants from single-component
/// to 4-component vectors are supported.
enum VertexAttributeType {
  /// 8-bit signed byte (1 component)
  BYTE,

  /// 8-bit signed byte vector (2 components)
  BYTE2,

  /// 8-bit signed byte vector (3 components)
  BYTE3,

  /// 8-bit signed byte vector (4 components)
  BYTE4,

  /// 8-bit unsigned byte (1 component)
  UBYTE,

  /// 8-bit unsigned byte vector (2 components)
  UBYTE2,

  /// 8-bit unsigned byte vector (3 components)
  UBYTE3,

  /// 8-bit unsigned byte vector (4 components)
  UBYTE4,

  /// 16-bit signed short (1 component)
  SHORT,

  /// 16-bit signed short vector (2 components)
  SHORT2,

  /// 16-bit signed short vector (3 components)
  SHORT3,

  /// 16-bit signed short vector (4 components)
  SHORT4,

  /// 16-bit unsigned short (1 component)
  USHORT,

  /// 16-bit unsigned short vector (2 components)
  USHORT2,

  /// 16-bit unsigned short vector (3 components)
  USHORT3,

  /// 16-bit unsigned short vector (4 components)
  USHORT4,

  /// 32-bit signed integer (1 component)
  INT,

  /// 32-bit unsigned integer (1 component)
  UINT,

  /// 32-bit float (1 component)
  FLOAT,

  /// 2-component float vector (8 bytes)
  FLOAT2,

  /// 3-component float vector (12 bytes)
  FLOAT3,

  /// 4-component float vector (16 bytes)
  FLOAT4,

  /// 16-bit half float (1 component)
  HALF,

  /// 2-component half float vector (4 bytes)
  HALF2,

  /// 3-component half float vector (6 bytes)
  HALF3,

  /// 4-component half float vector (8 bytes)
  HALF4,
}

/// Storage used by a [VertexBuffer]'s attribute streams.
enum VertexBufferStorageMode { unknown, direct, bufferObjects }

/// Holds a set of buffers that define the geometry of a Renderable.
///
/// The geometry is defined by vertex attributes such as position, color,
/// normals, tangents, etc. Attributes can be interleaved in the same buffer
/// or stored in separate buffers.
///
/// Buffers are GPU resources, so mutating their data can be relatively slow.
/// It's best to separate constant data from dynamic data into multiple buffers.
///
/// A single vertex buffer can be shared between multiple renderables.
abstract class VertexBuffer {
  /// Returns the number of vertices in this buffer.
  int getVertexCount();

  VertexBufferStorageMode get storageMode;

  bool get supportsSetBufferAt => storageMode == VertexBufferStorageMode.direct;

  /// Asynchronously copy-initializes the specified buffer from the given data.
  ///
  /// [bufferIndex] Index of the buffer to initialize (0 to bufferCount-1)
  /// [data] Raw vertex data to copy into the buffer
  /// [byteOffset] Offset in bytes into the buffer (default 0)
  ///
  /// Throws [StateError] when [supportsSetBufferAt] is false.
  Future setBufferAt(int bufferIndex, TypedData data, {int byteOffset = 0});

  /// Attaches a [BufferObject] to a stream.
  ///
  /// Throws [StateError] unless [storageMode] is
  /// [VertexBufferStorageMode.bufferObjects].
  Future<void> setBufferObjectAt(int bufferIndex, BufferObject bufferObject);

  /// Destroys this vertex buffer and releases GPU resources.
  ///
  /// The buffer must not be used after calling this method. Throws
  /// [StateError] when this is a borrowed buffer returned by a
  /// [ThermionAsset]. Destroy the owning asset instead.
  Future destroy();
}

/// Builder for creating VertexBuffer instances.
///
/// Usage example:
/// ```dart
/// final builder = VertexBufferBuilder()
///   ..bufferCount(2)
///   ..vertexCount(100)
///   ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
///   ..attribute(VertexAttribute.UV0, 1, VertexAttributeType.FLOAT2);
///
/// final vertexBuffer = await builder.build();
/// await vertexBuffer.setBufferAt(0, positions);
/// await vertexBuffer.setBufferAt(1, uvs);
/// ```
abstract class VertexBufferBuilder {
  /// Defines how many buffers will be created in this vertex buffer set.
  ///
  /// These buffers are later referenced by index from 0 to bufferCount - 1.
  /// This call is mandatory. Maximum value is 8.
  ///
  /// [count] Number of buffers in this vertex buffer set (1-8)
  void bufferCount(int count);

  /// Sets the number of vertices in each buffer.
  ///
  /// [count] Number of vertices in each buffer in this set
  void vertexCount(int count);

  /// Enables BufferObject-backed streams. Direct storage is used by default.
  void enableBufferObjects({bool enabled = true});

  /// Sets up an attribute for this vertex buffer.
  ///
  /// Attributes can be interleaved in the same buffer using byteOffset and byteStride.
  ///
  /// [attribute] The attribute to configure
  /// [bufferIndex] Index of the buffer containing this attribute (0 to bufferCount-1)
  /// [attributeType] Type of the attribute data
  /// [byteOffset] Offset in bytes into the buffer (default 0)
  /// [byteStride] Stride in bytes to the next element (default 0 = tightly packed)
  void attribute(
    VertexAttribute attribute,
    int bufferIndex,
    VertexAttributeType attributeType, {
    int byteOffset = 0,
    int byteStride = 0,
  });

  /// Sets whether an attribute should be normalized.
  ///
  /// A normalized attribute is mapped between 0 and 1 in the shader.
  /// This applies only to integer types.
  ///
  /// [attribute] The attribute to normalize
  /// [normalize] True to normalize (default true)
  void normalized(VertexAttribute attribute, {bool normalize = true});

  /// Creates the VertexBuffer object.
  ///
  /// After creation, the buffer is uninitialized. Use setBufferAt() to
  /// populate the buffer with vertex data.
  ///
  /// Returns the newly created VertexBuffer.
  Future<VertexBuffer> build();
}
