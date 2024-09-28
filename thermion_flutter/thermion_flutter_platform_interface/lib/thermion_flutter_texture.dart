// class ThermionFlutterTextureImpl {
//   final int width;
//   final int height;
//   final int? flutterTextureId;
//   final int? hardwareTextureId;
//   final int? surfaceAddress;
//   bool get usesBackingWindow => flutterTextureId == null;

//   ThermionFlutterTexture(this.flutterTextureId, this.hardwareTextureId,
//       this.width, this.height, this.surfaceAddress) {

//   }
// }

abstract class ThermionFlutterTexture {
  int get width;
  int get height;

  int get flutterId;
  int get hardwareId;

  ///
  /// Destroy a texture and clean up the texture cache (if applicable).
  ///
  Future destroy();

  Future resize(int width, int height, int left, int top);

  Future markFrameAvailable();
}
