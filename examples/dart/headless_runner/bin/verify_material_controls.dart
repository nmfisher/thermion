import 'dart:io';

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_examples_lib/examples_lib.dart';

/// Native rendering checks for the fiber, cosmic and thin-film examples.
/// Run from headless_runner, e.g.:
/// dart run bin/verify_material_controls.dart game_effects_iridescence
/// Requires a native GPU backend; this is intentionally not a unit test.
Future<void> main(List<String> args) async {
  const supported = {
    'game_effects_hair_fur',
    'game_effects_aurora',
    'game_effects_nebula',
    'game_effects_iridescence',
  };
  if (args.length != 1 || !supported.contains(args.single)) {
    stderr.writeln('Choose one of: ${supported.join(', ')}');
    exit(64);
  }
  final name = args.single;
  const size = 768, time = 3.2, later = 13.2;
  await FFIFilamentApp.create(
      config: FFIFilamentConfig(
          loadResource: (uri) =>
              File(uri.replaceFirst('file://', '')).readAsBytes()));
  final app = FilamentApp.instance! as FFIFilamentApp;
  final swapChain = await app.createHeadlessSwapChain(size, size);
  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(size, size);
  await registry[name]!(viewer,
      assetsDir: 'file://${Directory.current.path}/../../assets');
  // Compare shader behavior without frame-varying post-process dither noise.
  // Re-enable the scene's setting for the final appearance/extrema captures.
  final dithering = await viewer.view.isDitheringEnabled();
  await viewer.view.setDithering(false);
  final output = Directory('output/control_checks')
    ..createSync(recursive: true);

  Future<Float32List> frame(double t, String suffix) async {
    for (final animate in effectAnimators) {
      await animate(t);
    }
    final capture = await app.capture(swapChain,
        view: viewer.view,
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.FLOAT,
        render: true);
    final bytes = capture.first.$2;
    final pixels = Float32List.view(
        bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
    if (pixels.any((p) => !p.isFinite)) {
      throw StateError('Nonfinite pixels: $suffix');
    }
    final png = await pixelBufferToPng(bytes, size, size,
        hasAlpha: true, isFloat: true, linearToSrgb: true);
    await File('${output.path}/${name}_$suffix.png').writeAsBytes(png);
    return Float32List.fromList(pixels);
  }

  double difference(Float32List a, Float32List b) {
    var total = 0.0;
    for (var i = 0; i < a.length; i++) {
      if (i % 4 != 3) total += (a[i] - b[i]).abs();
    }
    return total / (a.length * .75);
  }

  void changed(Float32List a, Float32List b, String label) {
    final d = difference(a, b);
    stdout.writeln('$label MAE: $d');
    if (d < .00002) throw StateError('$label produced no visible change');
  }

  void unchanged(Float32List a, Float32List b, String label) {
    final d = difference(a, b);
    stdout.writeln('$label MAE: $d');
    if (d > .00001) throw StateError('$label unexpectedly changed');
  }

  Future<void> set(String label, double value) =>
      effectSliders.singleWhere((s) => s.label == label).setValue(value);
  Future<void> reset() async {
    for (final slider in effectSliders) {
      await slider.setValue(slider.initialValue);
    }
  }

  final baseline = await frame(time, 'baseline');
  changed(baseline, await frame(later, 'later'), 'Animation');
  final speedLabel = name.endsWith('hair_fur')
      ? 'Wind speed'
      : name.endsWith('iridescence')
          ? 'Flow speed'
          : 'Animation speed';
  await set(speedLabel, 0);
  unchanged(await frame(time, 'frozen'), await frame(later, 'frozen_later'),
      'Zero speed');
  await reset();

  if (name.endsWith('hair_fur')) {
    await set('Hair anisotropy', 0);
    changed(baseline, await frame(time, 'isotropic'), 'Hair anisotropy');
    await reset();
    await set('Fur length', 0);
    changed(baseline, await frame(time, 'shaved'), 'Fur length');
    await reset();
    await set('Wind strength', 0);
    unchanged(await frame(time, 'still'), await frame(later, 'still_later'),
        'Zero wind');
  } else if (name.endsWith('aurora')) {
    await set('Aurora brightness', 0);
    final clear = await frame(time, 'clear');
    changed(baseline, clear, 'Aurora brightness');
    unchanged(clear, await frame(later, 'clear_later'), 'Disabled aurora');
    await set('Stars', 0);
    changed(clear, await frame(time, 'no_stars'), 'Stars');
    await reset();
    await set('Color shift', 1);
    changed(baseline, await frame(time, 'alternate_color'), 'Aurora color');
  } else if (name.endsWith('nebula')) {
    await set('Dark dust', 0);
    changed(baseline, await frame(time, 'no_dust'), 'Dark dust');
    await reset();
    await set('Emission', 0);
    changed(baseline, await frame(time, 'no_emission'), 'Emission');
    await reset();
    await set('Gas density', 0);
    await set('Dark dust', 0);
    final clear = await frame(time, 'clear');
    changed(baseline, clear, 'Empty nebula');
    unchanged(clear, await frame(later, 'clear_later'), 'Empty sky');
  } else {
    await set('Iridescence', 0);
    changed(baseline, await frame(time, 'uncoated'), 'Iridescence');
    await reset();
    await set('Film thickness (nm)', 800);
    changed(baseline, await frame(time, 'thicker'), 'Film thickness');
    await reset();
    await set('Thickness variation', 0);
    unchanged(await frame(time, 'uniform'), await frame(later, 'uniform_later'),
        'Uniform film');
    await set('Film thickness (nm)', 0);
    await set('Film refractive index', 1.05);
    final bare = await frame(time, 'zero_thickness');
    await set('Film refractive index', 2.4);
    unchanged(bare, await frame(time, 'zero_thickness_high_ior'),
        'Zero-thickness film invariance');
  }

  // Maximum and minimum settings must stay finite, including the transparent
  // bubble, zero-length fur, and empty sky. Keep these captures for inspection.
  await viewer.view.setDithering(dithering);
  for (final slider in effectSliders) {
    await slider.setValue(slider.max);
  }
  await frame(time, 'maximum');
  for (final slider in effectSliders) {
    await slider.setValue(slider.min);
  }
  await frame(time, 'minimum');
  await reset();
  final camera = await viewer.getActiveCamera();
  if (name.endsWith('aurora') || name.endsWith('nebula')) {
    await camera.lookAt(Vector3(0, 1.7, 8), focus: Vector3(3, 20, 12));
  } else {
    await camera.lookAt(Vector3(-4, 2.8, -9), focus: Vector3(0, 1.3, 0));
  }
  await frame(time, 'alternate_view');
  stdout.writeln('PASS: $name');
  await stdout.flush();
  // Match run_example.dart: native teardown can deadlock after capture.
  exit(0);
}
