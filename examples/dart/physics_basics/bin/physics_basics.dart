import 'dart:io';

import 'package:physics_basics/physics_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Renders the physics_basics scene headlessly to a PNG or MP4 in output/.
///
///   dart run bin/physics_basics.dart [width] [height] [--time <seconds>] [--video [seconds] [fps]]
///
/// Defaults to a 512x512 still captured after 5.0 seconds of simulation (settled
/// pile). Pass `--time <seconds>` to capture an earlier moment, or `--video` to
/// render an animated MP4 via ffmpeg.
Future<void> main(List<String> args) async {
  final positional = <String>[];
  var video = false;
  var stillTime = 5.0;
  var videoSeconds = 5.0;
  var fps = 30;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--time' && i + 1 < args.length) {
      stillTime = double.parse(args[++i]);
    } else if (arg == '--video') {
      video = true;
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        videoSeconds = double.parse(args[++i]);
        if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
          fps = int.parse(args[++i]);
        }
      }
    } else if (!arg.startsWith('--')) {
      positional.add(arg);
    }
  }

  final width = positional.isNotEmpty ? int.parse(positional[0]) : 512;
  final height = positional.length > 1 ? int.parse(positional[1]) : 512;

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

  final scene = await PhysicsScene.create(
    viewer,
    assetsDir: 'file://${Directory.current.path}/../../assets',
  );

  Directory('output').createSync(recursive: true);

  Future<Uint8List> capturePng() async {
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
    final steps = (stillTime / PhysicsScene.fixedTimeStep).round();
    await scene.advanceFixed(steps);
    final png = await capturePng();
    const outPath = 'output/physics_basics.png';
    File(outPath).writeAsBytesSync(png);
    stdout.writeln('Saved $outPath');
    scene.dispose();
    await stdout.flush();
    exit(0);
  }

  final frameCount = (videoSeconds * fps).round();
  final framesDir = Directory('output/physics_basics_frames')
    ..createSync(recursive: true);
  final dt = 1.0 / fps;
  for (var i = 0; i < frameCount; i++) {
    if (i > 0) {
      await scene.step(dt);
    }
    final png = await capturePng();
    File('${framesDir.path}/frame_${i.toString().padLeft(5, '0')}.png')
        .writeAsBytesSync(png);
    if (i % 10 == 0) {
      stdout.writeln('frame $i/$frameCount');
      await stdout.flush();
    }
  }
  scene.dispose();

  const mp4Path = 'output/physics_basics.mp4';
  final ffmpeg = await Process.start('ffmpeg', [
    '-y',
    '-framerate',
    '$fps',
    '-i',
    '${framesDir.path}/frame_%05d.png',
    '-pix_fmt',
    'yuv420p',
    '-crf',
    '20',
    mp4Path,
  ]);
  ffmpeg.stderr.transform(SystemEncoding().decoder).listen(stderr.write);
  final code = await ffmpeg.exitCode;
  await stdout.flush();
  exit(code == 0 ? 0 : 1);
}
