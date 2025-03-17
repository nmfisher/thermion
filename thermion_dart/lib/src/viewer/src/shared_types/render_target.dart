import 'package:thermion_dart/thermion_dart.dart';

abstract class RenderTarget {
  Future<Texture> getColorTexture();
  Future<Texture> getDepthTexture();
}
