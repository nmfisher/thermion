import 'dart:typed_data';

import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFITexture extends Texture {
  final Pointer<TEngine> _engine;
  final Pointer<TTexture> pointer;

  FFITexture(this._engine, this.pointer);

  Future<void> setLinearImage(covariant FFILinearImage image,
      PixelDataFormat format, PixelDataType type,
      {int level = 0}) async {
    final tPixelDataFormat = format.value;
    final tPixelDataType = type.value;
    final result = await withBoolCallback((cb) {
      Texture_loadImageRenderThread(_engine, pointer, image.pointer,
          tPixelDataFormat, tPixelDataType, level, cb);
    });

    if (!result) {
      throw Exception("Failed to set linear image");
    }
  }

  @override
  Future<void> dispose() async {
    await withVoidCallback((requestId, cb) {
      Engine_destroyTextureRenderThread(_engine, pointer, requestId, cb);
    });
  }

  @override
  Future<void> generateMipmaps() async {
    await withVoidCallback((requestId, cb) => Texture_generateMipMapsRenderThread(pointer, _engine, requestId, cb));
  }

  @override
  Future<int> getDepth([int level = 0]) async {
    return Texture_getDepth(pointer, level);
  }

  @override
  Future<TextureFormat> getFormat() {
    // TODO: implement getFormat
    throw UnimplementedError();
  }

  @override
  Future<int> getHeight([int level = 0]) async {
    return Texture_getHeight(pointer, level);
  }

  @override
  Future<int> getLevels() async {
    return Texture_getLevels(pointer);
  }

  @override
  Future<TextureSamplerType> getTarget() {
    // TODO: implement getTarget
    throw UnimplementedError();
  }

  @override
  Future<int> getWidth([int level = 0]) async {
    return Texture_getWidth(pointer, level);
  }

  @override
  Future<void> setExternalImage(externalImage) {
    // TODO: implement setExternalImage
    throw UnimplementedError();
  }

  @override
  Future<void> setImage(int level, Uint8List buffer, int width, int height,
      int channels, PixelDataFormat format, PixelDataType type) async {
    final success = await withBoolCallback((cb) {
      Texture_setImageRenderThread(
          _engine,
          pointer,
          level,
          buffer.address,
          buffer.lengthInBytes,
          width,
          height,
          channels,
          format.index,
          type.index,
          cb);
    });

    if (!success) {
      throw Exception("Failed to set image");
    }
  }

  @override
  Future<void> setImage3D(
      int level,
      int xOffset,
      int yOffset,
      int zOffset,
      int width,
      int height,
      int channels,
      int depth,
      Uint8List buffer,
      PixelDataFormat format,
      PixelDataType type) async {
    throw UnimplementedError();
    // final success = await withBoolCallback((cb) {
    //   Texture_setImageWithDepthRenderThread(
    //       _engine,
    //       pointer,
    //       level,
    //       buffer.address,
    //       buffer.lengthInBytes,
    //       0,
    //       0,
    //       zOffset,
    //       width,
    //       height,
    //       channels,
    //       depth,
    //       format.index,
    //       type.index,
    //       cb);
    // });

    // if (!success) {
    //   throw Exception("Failed to set image");
    // }
  }

  @override
  Future<void> setSubImage(
      int level,
      int xOffset,
      int yOffset,
      int width,
      int height,
      Uint8List buffer,
      PixelDataFormat format,
      PixelDataType type) {
    // TODO: implement setSubImage
    throw UnimplementedError();
  }
}

class FFILinearImage extends LinearImage {
  final Pointer<TLinearImage> pointer;

  FFILinearImage(this.pointer);

  static Future<FFILinearImage> createEmpty(
      int width, int height, int channels) async {
    final imagePtr = await withPointerCallback<TLinearImage>((cb) {
      Image_createEmptyRenderThread(width, height, channels, cb);
    });

    return FFILinearImage(imagePtr);
  }

  static Future<FFILinearImage> decode(Uint8List data,
      {String name = "image", bool requireAlpha = false}) async {
    final image = await FilamentApp.instance!
        .decodeImage(data, name: name, requireAlpha: requireAlpha);
    return image as FFILinearImage;
  }

  Future<void> destroy() async {
    await withVoidCallback((requestId, cb) {
      Image_destroyRenderThread(this.pointer, requestId, cb);
    });
  }

  @override
  Future<int> getChannels() async {
    return await withUInt32Callback((cb) {
      Image_getChannelsRenderThread(pointer, cb);
    });
  }

  @override
  Future<int> getHeight() async {
    return await withUInt32Callback((cb) {
      Image_getHeightRenderThread(pointer, cb);
    });
  }

  @override
  Future<int> getWidth() async {
    return await withUInt32Callback((cb) {
      Image_getWidthRenderThread(pointer, cb);
    });
  }

  @override
  Future<Float32List> getData() async {
    final height = await getHeight();
    final width = await getWidth();
    final channels = await getChannels();

    final ptr = await withPointerCallback<Float>((cb) {
      Image_getBytesRenderThread(pointer, cb);
    });

    return ptr.asTypedList(height * width * channels);
  }
}

class FFITextureSampler extends TextureSampler {
  final Pointer<TTextureSampler> pointer;

  FFITextureSampler(this.pointer);

  static Future<FFITextureSampler> create() async {
    final samplerPtr = await withPointerCallback<TTextureSampler>((cb) {
      TextureSampler_createRenderThread(cb);
    });

    return FFITextureSampler(samplerPtr);
  }

  // static Future<FFITextureSampler> createWithFiltering(
  //     SamplerMinFilter minFilter,
  //     SamplerMagFilter magFilter,
  //     SamplerWrapMode wrapS,
  //     SamplerWrapMode wrapT,
  //     SamplerWrapMode wrapR) async {
  //   final samplerPtr = await withPointerCallback<TTextureSampler>((cb) {
  //     TextureSampler_createWithFilteringRenderThread(
  //       TSamplerMinFilter.values[minFilter.index],
  //       TSamplerMagFilter.values[magFilter.index],
  //       TSamplerWrapMode.values[wrapS.index],
  //       TSamplerWrapMode.values[wrapT.index],
  //       TSamplerWrapMode.values[wrapR.index],
  //       cb);
  //   });

  //   return FFITextureSampler(samplerPtr);
  // }

  // static Future<FFITextureSampler> createWithComparison(
  //     SamplerCompareMode compareMode,
  //     SamplerCompareFunc compareFunc) async {
  //   final samplerPtr = await withPointerCallback<TTextureSampler>((cb) {
  //     TextureSampler_createWithComparisonRenderThread(
  //       TSamplerCompareMode.values[compareMode.index],
  //       TTextureSamplerCompareFunc.values[compareFunc.index],
  //       cb);
  //   });

  //   return FFITextureSampler(samplerPtr);
  // }

  // Future<void> setMinFilter(SamplerMinFilter filter) async {
  //   await withVoidCallback((cb) {
  //     TextureSampler_setMinFilterRenderThread(
  //       pointer,
  //       TSamplerMinFilter.values[filter.index],
  //       cb);
  //   });
  // }

  // Future<void> setMagFilter(SamplerMagFilter filter) async {
  //   await withVoidCallback((cb) {
  //     TextureSampler_setMagFilterRenderThread(
  //       pointer,
  //       TSamplerMagFilter.values[filter.index],
  //       cb);
  //   });
  // }

  // Future<void> setWrapModeS(SamplerWrapMode mode) async {
  //   await withVoidCallback((cb) {
  //     TextureSampler_setWrapModeSRenderThread(
  //       pointer,
  //       TSamplerWrapMode.values[mode.index],
  //       cb);
  //   });
  // }

  // Future<void> setWrapModeT(SamplerWrapMode mode) async {
  //   await withVoidCallback((cb) {
  //     TextureSampler_setWrapModeTRenderThread(
  //       pointer,
  //       TSamplerWrapMode.values[mode.index],
  //       cb);
  //   });
  // }

  // Future<void> setWrapModeR(SamplerWrapMode mode) async {
  //   await withVoidCallback((cb) {
  //     TextureSampler_setWrapModeRRenderThread(
  //       pointer,
  //       TSamplerWrapMode.values[mode.index],
  //       cb);
  //   });
  // }

  Future<void> setAnisotropy(double anisotropy) async {
    await withVoidCallback((requestId, cb) {
      TextureSampler_setAnisotropyRenderThread(
          pointer, anisotropy, requestId, cb);
    });
  }

  // Future<void> setCompareMode(
  //     SamplerCompareMode mode, SamplerCompareFunc func) async {
  //   await withVoidCallback((cb) {
  //     TextureSampler_setCompareModeRenderThread(
  //       pointer,
  //       TSamplerCompareMode.values[mode.index],
  //       TTextureSamplerCompareFunc.values[func.index],
  //       cb);
  //   });
  // }

  @override
  Future dispose() async {
    await withVoidCallback((requestId, cb) {
      TextureSampler_destroyRenderThread(pointer, requestId, cb);
    });
  }
}
