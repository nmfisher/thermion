class FlutterFilamentTexture {
  final int width;
  final int height;
  final int? flutterTextureId;
  final int? hardwareTextureId;
  final int? surfaceAddress;
  bool get usesBackingWindow => flutterTextureId == null;

  FlutterFilamentTexture(this.flutterTextureId, this.hardwareTextureId,
      this.width, this.height, this.surfaceAddress) {

  }
}
