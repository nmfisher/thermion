import 'dart:ffi';

class FlutterFilamentTexture {
  final int width;
  final int height;
  final int flutterTextureId;
  final int? hardwareTextureId;
  Pointer<Void>? surface;

  FlutterFilamentTexture(this.flutterTextureId, this.hardwareTextureId,
      this.width, this.height, int? surfaceAddress) {
    if (surfaceAddress != null) {
      surface = Pointer<Void>.fromAddress(surfaceAddress!);
    }
  }
}
