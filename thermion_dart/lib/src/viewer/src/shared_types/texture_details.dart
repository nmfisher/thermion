///
/// This represents the backing "surface" that we render into.
/// "Texture" here is a misnomer as it is only a render target texture on certain platforms.
/// 
class TextureDetails {
  final int textureId;

  // both width and height are in physical, not logical pixels
  final int width;
  final int height;

  TextureDetails(
      {required this.textureId, required this.width, required this.height});
}
