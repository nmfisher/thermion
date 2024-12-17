class PlatformTextureDescriptor {
  final int flutterTextureId;
  final int hardwareId;
  final int? windowHandle;
  final int width;
  final int height;

  PlatformTextureDescriptor(this.flutterTextureId, this.hardwareId, this.windowHandle, this.width, this.height);
}

