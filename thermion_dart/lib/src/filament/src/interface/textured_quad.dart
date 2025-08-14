import 'package:thermion_dart/src/filament/src/interface/ktx1_bundle.dart';
import 'package:thermion_dart/thermion_dart.dart';

abstract class TexturedQuad extends ThermionAsset {
  int? get width;
  int? get height;

  Future destroy();

  ///
  ///
  Future setBackgroundColor(double r, double g, double b, double a);

  ///
  ///
  Future hideImage();

  ///
  ///
  Future setCubemapFace(int index);

  ///
  ///
  Future setImageFromKtxBundle(Ktx1Bundle bundle);

  ///
  ///
  Future setImage(Uint8List imageData);

  ///
  ///
  Future setImageFromTexture(Texture texture);

  ///
  ///
  Future setDepth(double depth);
}
