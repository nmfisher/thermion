import 'dart:io';
import 'dart:math' as math;

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_examples_lib/examples_lib.dart';

/// Captures the parallax example as an orbiting video (mp4 via ffmpeg).
///
///   dart run bin/parallax_video.dart [seconds] [fps] [width] [height]
///
/// POM is view-dependent: the camera sweeps from near-frontal (~15 deg from
/// the wall normal, where all three walls look alike) to grazing (~65 deg,
/// where the full-POM wall's relief diverges from the flat baseline) and
/// back. Default: 8s at 30fps, 1536x512.
Future<void> main(List<String> args) async {
  final seconds = args.isNotEmpty ? double.parse(args[0]) : 8.0;
  final fps = args.length > 1 ? int.parse(args[1]) : 30;
  final width = args.length > 2 ? int.parse(args[2]) : 1536;
  final height = args.length > 3 ? int.parse(args[3]) : 512;

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

  await setupParallax(
    viewer,
    assetsDir: 'file://${Directory.current.path}/../../assets',
  );

  final camera = await viewer.getActiveCamera();
  final framesDir = Directory('output/parallax_frames')..createSync(recursive: true);

  final frameCount = (seconds * fps).round();
  for (var i = 0; i < frameCount; i++) {
    final t = frameCount > 1 ? i / (frameCount - 1) : 0.0;
    // Smooth ping-pong: 0 -> 1 -> 0
    final s = math.sin(t * math.pi);

    final azimuth = (15.0 + 50.0 * s) * math.pi / 180.0;
    final radius = 3.2;
    final eye = Vector3(
      radius * math.sin(azimuth),
      0.55 + 0.15 * s,
      radius * math.cos(azimuth),
    );
    await camera.lookAt(eye, focus: Vector3(0.0, 0.5, 0.0));

    final pixels = (await FilamentApp.instance!.capture(
      swapChain,
      view: viewer.view,
      pixelDataFormat: PixelDataFormat.RGBA,
      pixelDataType: PixelDataType.FLOAT,
      render: true,
    ))
        .first
        .$2;
    final png = await pixelBufferToPng(
      pixels,
      width,
      height,
      hasAlpha: true,
      isFloat: true,
      linearToSrgb: true,
    );
    File('${framesDir.path}/${i.toString().padLeft(4, '0')}.png')
        .writeAsBytesSync(png);
    if (i % 30 == 0) {
      stdout.writeln('frame $i/$frameCount');
    }
  }

  stdout.writeln('encoding mp4...');
  final mp4Path = 'output/parallax.mp4';
  final ffmpeg = await Process.start('ffmpeg', [
    '-y',
    '-framerate', '$fps',
    '-i', '${framesDir.path}/%04d.png',
    '-c:v', 'libx264',
    '-pix_fmt', 'yuv420p',
    '-crf', '20',
    mp4Path,
  ]);
  ffmpeg.stderr.transform(SystemEncoding().decoder).listen(stderr.write);
  final code = await ffmpeg.exitCode;
  stdout.writeln(code == 0 ? 'Saved $mp4Path' : 'ffmpeg failed ($code)');
  await stdout.flush();
  exit(code == 0 ? 0 : 1);
}
