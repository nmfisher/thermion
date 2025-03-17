import 'dart:ffi';

import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIRenderTarget extends RenderTarget {
  final Pointer<TRenderTarget> renderTarget;
  final Pointer<TViewer> viewer;
  final Pointer<TEngine> engine;

  FFIRenderTarget(this.renderTarget, this.viewer, this.engine);

  @override
  Future<Texture> getColorTexture() async {
    final ptr = RenderTarget_getColorTexture(renderTarget);
    return FFITexture(engine, ptr);
  }

  @override
  Future<Texture> getDepthTexture() async {
    final ptr = RenderTarget_getDepthTexture(renderTarget);
    return FFITexture(engine, ptr);
  }
}
