import 'platform_texture_descriptor.dart';

/// Web-specific implementation that provides dimension info without hardware textures.
/// Unlike native implementations, this doesn't manage hardware textures
/// but provides dimension information for viewport/camera updates.
class WebPlatformTextureDescriptor extends PlatformTextureDescriptor {
  WebPlatformTextureDescriptor({required super.width, required super.height})
    : super(flutterTextureId: -1, hardwareId: -1, windowHandle: null);

  bool _destroyed = false;

  @override
  bool get destroyed => _destroyed;

  @override
  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    await releaseBinding();
  }

  @override
  Future<void> markTextureFrameAvailable() {
    // No-op on web - canvas updates handled by _ImageCopyingWidget
    return Future<void>.value();
  }
}
