import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

class FFIRenderTarget extends RenderTarget<Pointer<TRenderTarget>> {
  final Pointer<TRenderTarget> renderTarget;

  final FFIFilamentApp _app;

  FFIRenderTarget(this.renderTarget, this._app);

  @override
  Future<Texture> getColorTexture() async {
    final ptr = RenderTarget_getColorTexture(renderTarget);
    return FFITexture(_app.engine, ptr, _app);
  }

  @override
  Future<Texture> getDepthTexture() async {
    final ptr = RenderTarget_getDepthTexture(renderTarget);
    return FFITexture(_app.engine, ptr, _app);
  }

  @override
  Future destroy() async {
    await withVoidCallback(
      (requestId, cb) => RenderTarget_destroyRenderThread(_app.engine, renderTarget, requestId, cb),
    );
  }

  @override
  Pointer<TRenderTarget> getNativeHandle() {
    return this.renderTarget;
  }
}
