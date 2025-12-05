import 'dart:typed_data';

/// Type of indices stored in an IndexBuffer.
enum IndexType {
  /// 16-bit unsigned short indices (max 65,535 vertices)
  USHORT,

  /// 32-bit unsigned integer indices (max 4,294,967,295 vertices)
  UINT,
}

/// A buffer containing vertex indices into a VertexBuffer.
///
/// Indices can be 16 or 32 bit. The buffer itself is a GPU resource,
/// so mutating the data can be relatively slow. Typically these buffers
/// are constant.
///
/// A single index buffer can be shared between multiple renderables.
abstract class IndexBuffer {
  /// Returns the number of indices in this buffer.
  int getIndexCount();

  /// Asynchronously copy-initializes this buffer from the given data.
  ///
  /// The data should be either Uint16List for USHORT indices or
  /// Uint32List for UINT indices.
  ///
  /// [data] Index data to copy into the buffer
  /// [byteOffset] Offset in bytes into the buffer (default 0)
  Future setBuffer(TypedData data, {int byteOffset = 0});

  /// Destroys this index buffer and releases GPU resources.
  ///
  /// The buffer must not be used after calling this method.
  Future destroy();
}

/// Builder for creating IndexBuffer instances.
///
/// Usage example:
/// ```dart
/// final builder = IndexBufferBuilder()
///   ..indexCount(300)
///   ..bufferType(IndexType.USHORT);
///
/// final indexBuffer = await builder.build();
/// await indexBuffer.setBuffer(indices);
/// ```
abstract class IndexBufferBuilder {
  /// Sets the number of indices in the buffer.
  ///
  /// [count] Number of indices the IndexBuffer can hold
  void indexCount(int count);

  /// Sets the type of indices (16-bit or 32-bit).
  ///
  /// [type] Type of indices stored in the buffer
  void bufferType(IndexType type);

  /// Creates the IndexBuffer object.
  ///
  /// After creation, the buffer is uninitialized. Use setBuffer() to
  /// populate the buffer with index data.
  ///
  /// Returns the newly created IndexBuffer.
  Future<IndexBuffer> build();
}
