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
