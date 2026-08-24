// Pure-Dart headless example: render an animated glTF frame-by-frame to PNGs,
// using the accumulated-clock animationManager.update pattern.
//
// Run with:  dart run dart_animation_render.dart [assets_dir] [frames]
// (defaults: assets_dir=examples/assets, frames=10)
//
// Adapted from examples/dart/cli_headless/bin/render_demo.dart in the thermion
// repository.

import 'dart:io' as io;

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

Future<void> main(List<String> argv) async {
  final assetsDir = argv.isNotEmpty ? argv.first : 'examples/assets';
  final frameCount = argv.length > 1 ? int.parse(argv[1]) : 10;
  const fps = 30;
  const width = 512, height = 512;
  final assetUri = (String rel) => 'file://$assetsDir/$rel';

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(
      loadResource: (uri) async =>
          io.File(uri.replaceAll('file://', '')).readAsBytes(),
    ),
  );
  final app = FilamentApp.instance!;
  final swapChain = await app.createHeadlessSwapChain(width, height);
  final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setViewport(width, height);

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(3, 2, 3), focus: Vector3(0, 0, 0));

  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));

  final asset = await viewer.loadGltf(assetUri('BusterDrone/scene.gltf'));
  await asset.transformToUnitCube();
  await asset.addAnimationComponent();

  final clipNames = await asset.getGltfAnimationNames();
  print('Clips: $clipNames');
  final duration = await asset.getGltfAnimationDuration(0);
  print('Clip 0 duration: ${duration.toStringAsFixed(2)}s');

  // playGltfAnimation + update is the right tool for continuous playback.
  // (setGltfAnimationTime is also safe for morph clips — render-thread
  // dispatched — but is meant for scrubbing to an exact time.)
  await asset.playGltfAnimation(0, loop: true, speed: 1.0);

  // update() takes an ABSOLUTE monotonic clock (nanos), not a delta —
  // accumulate one frame's worth per iteration. Starting at dtNanos (not 0)
  // triggers the manager's first-call sentinel exactly once; the first update
  // applies animation frame 0.
  final dtNanos = (1e9 / fps).round();
  var clockNanos = 0;

  final outDir = io.Directory('anim_frames')..createSync(recursive: true);
  for (var i = 0; i < frameCount; i++) {
    clockNanos += dtNanos;
    await app.animationManager.update(clockNanos);

    final result = await app.capture(
      swapChain,
      view: viewer.view,
      pixelDataFormat: PixelDataFormat.RGBA,
      pixelDataType: PixelDataType.FLOAT,
    );
    final png = await pixelBufferToPng(result.first.$2, width, height,
        hasAlpha: true, isFloat: true);
    await io.File('${outDir.path}/frame_${i.toString().padLeft(4, '0')}.png')
        .writeAsBytes(png);
  }
  print('Wrote $frameCount frames to ${outDir.path}');

  io.exit(0);
}
