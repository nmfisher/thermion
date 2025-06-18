import 'dart:io';
import 'dart:isolate';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

void main() async {
  await FFIFilamentApp.create();
  final (width, height) = (500, 500);
  final sc = await FilamentApp.instance!.createHeadlessSwapChain(width, height);
  var viewer = ThermionViewerFFI();
  await viewer.initialized;

  await FilamentApp.instance!.register(sc, viewer.view);

  await viewer.view.setFrustumCullingEnabled(false);
  await viewer.setBackgroundColor(1, 0, 1, 1);
  await viewer.setViewport(width, height);
  final result = await FilamentApp.instance!.capture(
    sc,
    view: viewer.view,
  );

  final bitmap = await pixelBufferToBmp(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);

  var outfile = File("output/render.bmp");
  outfile.parent.create();
  outfile.writeAsBytesSync(bitmap);
  await FilamentApp.instance!.destroy();
  Isolate.current.kill();
}
