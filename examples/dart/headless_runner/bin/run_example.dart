import 'dart:io';

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_examples_lib/examples_lib.dart';

/// Renders a registered example headlessly and writes a PNG to output/.
///
///   dart run bin/run_example.dart <name> [width] [height] [--time <seconds>] [--video [seconds] [fps]]
///
/// <name> must be a key in [registry]. Defaults to `load_gltf` at 512x512.
///
/// Stills render at the animators' t=0 state by default; pass `--time` to
/// capture a specific point in the animation instead (the setups' golden
/// times are otherwise stomped by the animator call).
///
/// With `--video`, advances the example's registered [effectAnimators] by
/// wall-clock seconds per frame, captures each frame to
/// output/<name>_frames/, then encodes output/<name>.mp4 with ffmpeg
/// (frames are left on disk if ffmpeg is unavailable).
Future<void> main(List<String> args) async {
  final name = args.isNotEmpty ? args[0] : 'load_gltf';
  final width = args.length > 1 ? int.parse(args[1]) : 512;
  final height = args.length > 2 ? int.parse(args[2]) : 512;
  final videoIndex = args.indexOf('--video');
  final video = videoIndex >= 0;
  final timeIndex = args.indexOf('--time');
  final stillTime =
      timeIndex >= 0 && args.length > timeIndex + 1 ? double.parse(args[timeIndex + 1]) : 0.0;
  final seconds = video && args.length > videoIndex + 1
      ? double.parse(args[videoIndex + 1])
      : 4.0;
  final fps = video && args.length > videoIndex + 2
      ? int.parse(args[videoIndex + 2])
      : 30;
  final setup = registry[name];
  if (setup == null) {
    stderr.writeln('Unknown example: $name');
    stderr.writeln('Available: ${registry.keys.join(', ')}');
    exit(1);
  }

  // Native file-based resource loader. assetsDir is repo-relative; the examples
  // live under examples/dart/<pkg>/, so ../../assets resolves to examples/assets.
  Future<Uint8List> loadResource(String uri) async {
    final path = uri.replaceAll('file://', '');
    return File(path).readAsBytesSync();
  }

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(loadResource: loadResource),
  );

  final swapChain =
      await FilamentApp.instance!.createHeadlessSwapChain(width, height);
  final viewer = ThermionViewerFFI(app: FilamentApp.instance! as FFIFilamentApp);
  await viewer.initialized;
  await FilamentApp.instance!.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(width, height);

  await setup(viewer, assetsDir: 'file://${Directory.current.path}/../../assets');

  Directory('output').createSync(recursive: true);

  // Renders one frame with the animators advanced to [t] and returns PNG
  // bytes. Parameters set before capture() persist on the instances, and
  // capture() bypasses requestFrame hooks - so animation must be applied
  // through the animators rather than frame hooks.
  Future<Uint8List> frameAt(double t) async {
    for (final animate in effectAnimators) {
      await animate(t);
    }
    final pixelBuffers = await FilamentApp.instance!.capture(
      swapChain,
      view: viewer.view,
      pixelDataFormat: PixelDataFormat.RGBA,
      pixelDataType: PixelDataType.FLOAT,
      render: true,
    );
    return pixelBufferToPng(
      pixelBuffers.first.$2,
      width,
      height,
      hasAlpha: true,
      isFloat: true,
      linearToSrgb: true,
    );
  }

  if (!video) {
    // Capture a single rendered frame and save it.
    final png = await frameAt(stillTime);
    final outPath = 'output/$name.png';
    File(outPath).writeAsBytesSync(png);
    stdout.writeln('Saved $outPath');

    // Exit immediately after the capture. Full engine teardown is unreliable
    // here: destroying a material instance still assigned to a renderable
    // deadlocks, and Filament panics when a material is destroyed while
    // instances remain alive. The PNG is already on disk and the process is
    // finished, so reclaiming engine resources buys nothing.
    await stdout.flush();
    exit(0);
  }

  final frameCount = (seconds * fps).round();
  final framesDir = Directory('output/${name}_frames')
    ..createSync(recursive: true);
  for (var i = 0; i < frameCount; i++) {
    final png = await frameAt(i / fps);
    File('${framesDir.path}/frame_${i.toString().padLeft(5, '0')}.png')
        .writeAsBytesSync(png);
    if (i % 10 == 0) {
      stdout.writeln('frame $i/$frameCount');
      await stdout.flush();
    }
  }

  final mp4Path = 'output/$name.mp4';
  final ffmpeg = await Process.start('ffmpeg', [
    '-y',
    '-framerate', '$fps',
    '-i', '${framesDir.path}/frame_%05d.png',
    '-pix_fmt', 'yuv420p',
    '-crf', '20',
    mp4Path,
  ]);
  ffmpeg.stderr.transform(SystemEncoding().decoder).listen(stderr.write);
  final code = await ffmpeg.exitCode;
  await stdout.flush();
  exit(code == 0 ? 0 : 1);
}
