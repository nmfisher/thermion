import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFISkybox extends Skybox {
  final Pointer<TSkybox> pointer;

  FFISkybox(this.pointer);

  @override
  Future setColor(double r, double g, double b, double a) async {
    Skybox_setColor(pointer, r, g, b, a);
  }

  @override
  Future destroy() async {
    await withVoidCallback(
      (requestId, cb) => Engine_destroySkyboxRenderThread(
        (FilamentApp.instance as FFIFilamentApp).engine,
        pointer,
        requestId,
        cb,
      ),
    );
  }
}
