import 'dart:io';
import 'dart:math' as math;

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

import '../../examples_lib/lib/src/interior_mapping.dart';

/// Run from headless_runner:
/// dart run bin/interior_mapping_video.dart [seconds] [fps] [width] [height]
/// Requires ffmpeg on PATH. Defaults to an eight-second 1280x720 orbit.
Future<void> main(List<String> args) async {
  final seconds = args.isNotEmpty ? double.parse(args[0]) : 8.0;
  final fps = args.length > 1 ? int.parse(args[1]) : 30;
  final width = args.length > 2 ? int.parse(args[2]) : 1280;
  final height = args.length > 3 ? int.parse(args[3]) : 720;
  if (!seconds.isFinite ||
      seconds <= 0 ||
      fps <= 0 ||
      width <= 0 ||
      height <= 0 ||
      width.isOdd ||
      height.isOdd) {
    throw ArgumentError(
        'Use positive duration/fps and positive, even dimensions');
  }
  await FFIFilamentApp.create(
    config: FFIFilamentConfig(
        loadResource: (uri) =>
            File(uri.replaceFirst('file://', '')).readAsBytes()),
  );
  final app = FilamentApp.instance! as FFIFilamentApp;
  final swapChain = await app.createHeadlessSwapChain(width, height);
  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(width, height);
  await app.renderManager.setRenderable(viewer.view, false);
  await setupInteriorMapping(viewer,
      assetsDir: 'file://${Directory.current.path}/../../assets');
  await captureInteriorMappingVideo(viewer, swapChain,
      output: Directory('output'),
      seconds: seconds,
      fps: fps,
      width: width,
      height: height);
  await stdout.flush();
  // Match the other CLI captures: process exit releases engine resources.
  exit(0);
}

/// Also usable with an existing headless viewer, including the GPU test host.
Future<void> captureInteriorMappingVideo(
  ThermionViewer viewer,
  SwapChain swapChain, {
  required Directory output,
  double seconds = 8,
  int fps = 30,
  int width = 1280,
  int height = 720,
}) async {
  final frames = Directory('${output.path}/interior_mapping_frames')
    ..createSync(recursive: true);
  final camera = await viewer.getActiveCamera();
  final frameCount = math.max(1, (seconds * fps).round());
  await FilamentApp.instance!.renderManager.setRenderable(viewer.view, false);
  for (var i = 0; i < frameCount; i++) {
    final phase = frameCount > 1 ? i / (frameCount - 1) : 0.0;
    // Reach grazing incidence so the glass Fresnel reflection is visible.
    final angle = math.sin(phase * 2 * math.pi) * 70 * math.pi / 180;
    await camera.lookAt(
      Vector3(7.8 * math.sin(angle), 1.4 * math.cos(phase * 2 * math.pi),
          7.8 * math.cos(angle)),
      focus: Vector3.zero(),
    );
    final pixels = (await FilamentApp.instance!.capture(swapChain,
            view: viewer.view,
            pixelDataFormat: PixelDataFormat.RGBA,
            pixelDataType: PixelDataType.FLOAT,
            render: true))
        .first
        .$2;
    final png = await pixelBufferToPng(pixels, width, height,
        hasAlpha: true, isFloat: true, linearToSrgb: true);
    File('${frames.path}/${i.toString().padLeft(4, '0')}.png')
        .writeAsBytesSync(png);
    if (i % fps == 0) stdout.writeln('Frame $i / $frameCount');
  }
  final video = '${output.path}/interior_mapping.mp4';
  final result = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-framerate',
    '$fps',
    '-i',
    '${frames.path}/%04d.png',
    '-frames:v',
    '$frameCount',
    '-c:v',
    'libx264',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '20',
    '-movflags',
    '+faststart',
    video,
  ]);
  if (result.exitCode != 0) throw StateError('ffmpeg failed: ${result.stderr}');
  stdout.writeln('Saved $video');
}
