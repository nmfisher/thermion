import 'dart:io';

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_examples_lib/examples_lib.dart';

/// Renders a registered example headlessly and writes a PNG to output/.
///
///   dart run <name> [width] [height]
///
/// <name> must be a key in [registry]. Defaults to `load_gltf` at 512x512.
Future<void> main(List<String> args) async {
  final name = args.isNotEmpty ? args[0] : 'load_gltf';
  final width = args.length > 1 ? int.parse(args[1]) : 512;
  final height = args.length > 2 ? int.parse(args[2]) : 512;
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

  // Capture a single rendered frame and save it.
  Directory('output').createSync(recursive: true);
  final pixelBuffers = await FilamentApp.instance!.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
    render: true,
  );
  final pixels = pixelBuffers.first.$2;
  final png = await pixelBufferToPng(
    pixels,
    width,
    height,
    hasAlpha: true,
    isFloat: true,
    linearToSrgb: true,
  );
  final outPath = 'output/$name.png';
  File(outPath).writeAsBytesSync(png);
  stdout.writeln('Saved $outPath');

  // Exit immediately after the capture. Full engine teardown is unreliable
  // here: destroying a material instance that is still assigned to a
  // renderable deadlocks, and Filament panics when a material is destroyed
  // while instances remain alive. The PNG is already on disk and the process
  // is finished, so reclaiming engine resources buys nothing.
  await stdout.flush();
  exit(0);
}
