abstract class PlatformTextureDescriptor {
  final int flutterTextureId;
  int hardwareId;
  final int? windowHandle;
  int width;
  int height;

  PlatformTextureDescriptor(
      {required this.flutterTextureId,
      required this.hardwareId,
      this.windowHandle,
      required this.width,
      required this.height});

  void markTextureFrameAvailable();
  Future destroy();

  Future Function(Duration timestamp)? onBeginFrame;
}
