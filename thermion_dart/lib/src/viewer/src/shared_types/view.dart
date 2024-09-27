import 'package:thermion_dart/thermion_dart.dart';

abstract class View {
  Future updateViewport(int width, int height);
  Future setRenderTarget(covariant RenderTarget renderTarget);
}
