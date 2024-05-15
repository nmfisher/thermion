class FlutterFilamentTexture {
  final int width;
  final int height;
  final int flutterTextureId;
  final int? hardwareTextureId;
  final int? surfaceAddress;

  FlutterFilamentTexture(this.flutterTextureId, this.hardwareTextureId,
      this.width, this.height, this.surfaceAddress) {
        // surface = surfaceAddress
    // if (surfaceAddress != null) {
    //   surface = Pointer<Void>.fromAddress(surfaceAddress!);
    // }
  }
}
