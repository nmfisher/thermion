abstract class PlatformTextureDescriptor {
  final int flutterTextureId;
  final int hardwareId;
  final int? windowHandle;
  final int width;
  final int height;

  bool get destroyed;

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
