import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIRenderTarget extends RenderTarget<Pointer<TRenderTarget>> {
  final Pointer<TRenderTarget> renderTarget;
  final FFIFilamentApp app;

  FFIRenderTarget(this.renderTarget, this.app);

  @override
  Future<Texture> getColorTexture() async {
    final ptr = RenderTarget_getColorTexture(renderTarget);
    return FFITexture(app.engine, ptr);
  }

  @override
  Future<Texture> getDepthTexture() async {
    final ptr = RenderTarget_getDepthTexture(renderTarget);
    return FFITexture(app.engine, ptr);
  }

  @override
  Future destroy() async {
    await withVoidCallback((requestId, cb) => RenderTarget_destroyRenderThread(
        app.engine, renderTarget, requestId, cb));
  }

  @override
  Pointer<TRenderTarget> getNativeHandle() {
    return this.renderTarget;
  }
}
