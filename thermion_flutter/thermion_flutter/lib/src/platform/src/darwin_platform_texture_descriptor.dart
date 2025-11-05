import 'package:thermion_flutter/src/swift/swift_bindings.g.dart';
import 'platform_texture_descriptor.dart';

class DarwinPlatformTextureDescriptorImpl extends PlatformTextureDescriptor {
  final MetalTextureWrapper texture;
  bool destroyed = false;

  DarwinPlatformTextureDescriptorImpl(this.texture,
      {required super.flutterTextureId,
      required super.hardwareId,
      required super.width,
      required super.height});

  @override
  Future destroy() async {
    if (destroyed) {
      throw Exception();
    }
    SwiftThermionFlutterPluginObjCAPI
        .unregisterFlutterTextureWithFlutterTextureId_(flutterTextureId);
    texture.release();
    destroyed = true;
  }

  @override
  void markTextureFrameAvailable() async {
    SwiftThermionFlutterPluginObjCAPI
        .markTextureFrameAvailableWithFlutterTextureId_(flutterTextureId);
  }

  static DarwinPlatformTextureDescriptorImpl allocate(int width, int height) {
    final metalTexture = MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(width,
        height, false, false);
    metalTexture.retain();
    final flutterTextureId =
        SwiftThermionFlutterPluginObjCAPI.registerTextureWithTexture_(
            metalTexture);
    if (flutterTextureId == -1) {
      throw Exception("Failed to register Flutter texture");
    }
    return DarwinPlatformTextureDescriptorImpl(metalTexture,
        flutterTextureId: flutterTextureId,
        hardwareId: metalTexture.metalTextureAddress,
        width: width,
        height: height);
  }
}
