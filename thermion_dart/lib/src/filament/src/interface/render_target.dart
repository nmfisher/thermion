import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

abstract class RenderTarget<T> extends NativeHandle {
  Future<Texture> getColorTexture();
  Future<Texture> getDepthTexture();
  
  // Destroy the render target. Does not destroy any attached textures; these
  // must be destroyed individually. 
  Future destroy();
}
