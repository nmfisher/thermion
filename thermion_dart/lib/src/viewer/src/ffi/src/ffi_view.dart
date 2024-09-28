import 'dart:ffi';

import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/camera.dart';

import '../../shared_types/view.dart';
import '../thermion_viewer_ffi.dart';
import 'thermion_viewer_ffi.dart';

class FFIView extends View {
  final Pointer<TView> view;
  final Pointer<TViewer> viewer;

  FFIView(this.view, this.viewer);

  @override
  Future updateViewport(int width, int height) async {
    View_updateViewport(view, width, height);
  }

  @override
  Future setRenderTarget(covariant FFIRenderTarget renderTarget) async {
    View_setRenderTarget(view, renderTarget.renderTarget);
  }

  @override
  Future setCamera(FFICamera camera) async {
    View_setCamera(view, camera.camera);
  }

  @override
  Future<Viewport> getViewport() async {
    TViewport vp = View_getViewport(view);
    return Viewport(vp.left, vp.bottom, vp.width, vp.height);
  }

  @override
  Camera getCamera() {
    final engine = Viewer_getEngine(viewer);
    return FFICamera(View_getCamera(view), engine);
  }
}
