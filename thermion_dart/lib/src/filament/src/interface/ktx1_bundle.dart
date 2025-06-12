import 'package:thermion_dart/thermion_dart.dart';

abstract class Ktx1Bundle {
  
  ///
  ///
  ///
  bool isCubemap();

  ///
  ///
  ///
  Future<Texture> createTexture();

  ///
  ///
  ///
  Float32List getSphericalHarmonics();

  ///
  ///
  ///
  Future destroy();
}
