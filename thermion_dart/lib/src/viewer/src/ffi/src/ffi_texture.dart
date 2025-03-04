import 'dart:typed_data';

import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFITexture extends Texture {
  final Pointer<TEngine> _engine;
  final Pointer<TTexture> pointer;

  FFITexture(this._engine, this.pointer);

  Future setLinearImage(covariant FFILinearImage image, PixelDataFormat format,
      PixelDataType type) async {
    final result = Texture_loadImage(
        _engine,
        pointer,
        image.pointer,
        TPixelDataFormat.values[format.index],
        TPixelDataType.values[type.index]);
    if (!result) {
      throw Exception("Failed to set linear image");
    }
  }

  @override
  Future dispose() async {
    Engine_destroyTexture(_engine, pointer);
  }

  @override
  Future generateMipmaps() {
    // TODO: implement generateMipmaps
    throw UnimplementedError();
  }

  @override
  Future<int> getDepth([int level = 0]) {
    // TODO: implement getDepth
    throw UnimplementedError();
  }

  @override
  Future<TextureFormat> getFormat() {
    // TODO: implement getFormat
    throw UnimplementedError();
  }

  @override
  Future<int> getHeight([int level = 0]) {
    // TODO: implement getHeight
    throw UnimplementedError();
  }

  @override
  Future<int> getLevels() {
    // TODO: implement getLevels
    throw UnimplementedError();
  }

  @override
  Future<TextureSamplerType> getTarget() {
    // TODO: implement getTarget
    throw UnimplementedError();
  }

  @override
  Future<int> getWidth([int level = 0]) {
    // TODO: implement getWidth
    throw UnimplementedError();
  }

  @override
  Future setExternalImage(externalImage) {
    // TODO: implement setExternalImage
    throw UnimplementedError();
  }

  @override
  Future setImage(int level, Uint8List buffer, int width, int height,
      int channels, PixelDataFormat format, PixelDataType type) async {
    final success = Texture_setImage(
        _engine,
        pointer,
        level,
        buffer.address,
        buffer.lengthInBytes,
        width,
        height,
        channels,
        format.index,
        type.index);
    if (!success) {
      throw Exception("Failed to set image");
    }
  }

  @override
  Future setImage3D(
      int level,
      int xOffset,
      int yOffset,
      int zOffset,
      int width,
      int height,
      int depth,
      Uint8List buffer,
      PixelDataFormat format,
      PixelDataType type) {
    // TODO: implement setImage3D
    throw UnimplementedError();
  }

  @override
  Future setSubImage(int level, int xOffset, int yOffset, int width, int height,
      Uint8List buffer, PixelDataFormat format, PixelDataType type) {
    // TODO: implement setSubImage
    throw UnimplementedError();
  }
}

class FFILinearImage extends LinearImage {
  final Pointer<TLinearImage> pointer;

  FFILinearImage(this.pointer);

  Future destroy() async {
    Image_destroy(this.pointer);
  }

  @override
  Future<int> getChannels() async {
    return Image_getChannels(pointer);
  }

  @override
  Future<int> getHeight() async {
    return Image_getHeight(pointer);
  }

  @override
  Future<int> getWidth() async {
    return Image_getWidth(pointer);
  }

  @override
  Future<Float32List> getData() async {
    final height = await getHeight();
    final width = await getWidth();
    final channels = await getChannels();
    final ptr = Image_getBytes(pointer);
    return ptr.asTypedList(height * width * channels);
  }
}
