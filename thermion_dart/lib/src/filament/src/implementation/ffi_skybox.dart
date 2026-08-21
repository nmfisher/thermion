import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFISkybox extends Skybox {
  final Pointer<TSkybox> pointer;

  final FFIFilamentApp _app;

  FFISkybox(this.pointer, this._app);

  @override
  Future setColor(double r, double g, double b, double a) async {
    Skybox_setColor(pointer, r, g, b, a);
  }

  @override
  Future setLayerMask(int select, int values) async {
    Skybox_setLayerMask(pointer, select, values);
  }

  @override
  int getLayerMask() {
    return Skybox_getLayerMask(pointer);
  }

  @override
  double getIntensity() {
    return Skybox_getIntensity(pointer);
  }

  @override
  Texture? getTexture() {
    final ptr = Skybox_getTexture(pointer);
    if (ptr == nullptr) {
      return null;
    }
    return FFITexture(_app.engine, ptr, _app);
  }

  @override
  Future destroy() async {
    await withVoidCallback((requestId, cb) => Engine_destroySkyboxRenderThread(_app.engine, pointer, requestId, cb));
  }
}
