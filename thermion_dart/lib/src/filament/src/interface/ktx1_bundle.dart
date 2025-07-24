import 'package:thermion_dart/thermion_dart.dart';

abstract class Ktx1Bundle {
  ///
  ///
  ///
  bool isCubemap();

  ///
  ///
  ///
  Future<Texture> createTexture(
      {VoidCallback? onTextureUploadComplete, int? textureUploadCompleteRequestId});

  ///
  ///
  ///
  Float32List getSphericalHarmonics();

  ///
  ///
  ///
  Future destroy();
}
