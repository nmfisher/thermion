import 'dart:typed_data';

/// GPU storage that can be shared or swapped between compatible vertex
/// buffers.
abstract class BufferObject {
  Future<void> setBuffer(TypedData data, {int byteOffset = 0});

  Future<void> destroy();
}

abstract class BufferObjectBuilder {
  void size(int sizeInBytes);

  Future<BufferObject> build();
}
