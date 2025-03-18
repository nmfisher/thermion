import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_swapchain.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/scene.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/shared_types.dart';
import 'callbacks.dart';
import 'ffi_camera.dart';

class FFIScene extends Scene {
  final Pointer<TScene> scene;
  final FFIFilamentApp app;

  FFIRenderTarget? renderTarget;

  FFIScene(this.scene, this.app) {
    
  }

}
