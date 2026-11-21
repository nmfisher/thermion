import 'dart:convert';
import 'dart:io';

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_examples_lib/examples_lib.dart';

/// Uncapped, serialized native frame measurement (CPU + GPU + FFI/fence waits).
/// No PNG encoding, pixel readback, Flutter compositor or frame cap is timed.
/// Run from headless_runner. --ablate also measures effects individually disabled
/// and sequential uniform updates as a reference for batching.
Future<void> main(List<String> args) async {
  String option(String name, String fallback) => args
      .firstWhere((a) => a.startsWith('--$name='),
          orElse: () => '--$name=$fallback')
      .split('=')
      .skip(1)
      .join('=');
  if (args.contains('--help')) {
    print('dart run bin/benchmark_showcase.dart [--width=960] [--height=640] '
        '[--frames=120] [--warmup=24] [--backend=default|metal|vulkan|opengl] '
        '[--output=output/showcase_performance.json] [--ablate] [--capture] '
        '[--verify]');
    return;
  }
  final width = int.parse(option('width', '960'));
  final height = int.parse(option('height', '640'));
  final frames = int.parse(option('frames', '120'));
  final warmup = int.parse(option('warmup', '24'));
  if (width < 64 ||
      height < 64 ||
      width > 3840 ||
      height > 3840 ||
      frames < 30 ||
      frames > 10000 ||
      warmup < 1) {
    throw ArgumentError(
        'Use 64–3840 pixels, 30–10000 frames, and at least one warm-up frame.');
  }
  final backendName = option('backend', 'default');
  final backend = switch (backendName) {
    'default' => Backend.DEFAULT,
    'metal' => Backend.METAL,
    'vulkan' => Backend.VULKAN,
    'opengl' => Backend.OPENGL,
    _ => throw ArgumentError('Unknown backend: $backendName'),
  };
  await FFIFilamentApp.create(
      config: FFIFilamentConfig(
          backend: backend,
          loadResource: (uri) =>
              File(uri.replaceFirst('file://', '')).readAsBytes()));
  final app = FilamentApp.instance! as FFIFilamentApp;
  final swapChain = await app.createHeadlessSwapChain(width, height);
  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(width, height);
  final scene = await EffectsShowcase.create(viewer,
      assetsDir: 'file://${Directory.current.path}/../../assets');
  final cases = <(String, ShowcaseQuality, ShowcaseEffect?, bool)>[
    for (final q in ShowcaseQuality.values) (q.name, q, null, true),
    if (args.contains('--ablate')) ...[
      for (final effect in ShowcaseEffect.values)
        (
          'balanced_without_${effect.name}',
          ShowcaseQuality.balanced,
          effect,
          true
        ),
      ('balanced_sequential_updates', ShowcaseQuality.balanced, null, false),
    ],
  ];
  final results = <Map<String, Object?>>[];
  final output = File(option('output', 'output/showcase_performance.json'));
  await output.parent.create(recursive: true);
  Future<Uint8List> capture() async {
    final pixels = await app.capture(swapChain,
        view: viewer.view,
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.FLOAT,
        render: true);
    final bytes = pixels.first.$2;
    final values = Float32List.view(
        bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
    if (values.any((v) => !v.isFinite)) {
      throw StateError('Nonfinite pixels');
    }
    return Uint8List.fromList(bytes);
  }

  for (final spec in cases) {
    await scene.setQuality(spec.$2);
    for (final effect in ShowcaseEffect.values) {
      await scene.setEnabled(effect, effect != spec.$3);
    }
    scene.batchUpdates = spec.$4;
    final total = FrameSamples(capacity: frames);
    final update = FrameSamples(capacity: frames);
    // Warm the same shader variants and camera positions used in measurement.
    for (var i = -warmup; i < frames; i++) {
      final phase = (i < 0 ? (i + warmup) / warmup : i / frames) * 20;
      final elapsed = Stopwatch()..start();
      await scene.setTour(phase);
      await scene.update(3.2 + phase);
      final updateUs = elapsed.elapsedMicroseconds;
      // renderSingleFrame ends with Engine::flushAndWait, including the GPU
      // finish operation. This is a serialized wall-clock metric, not GPU-only
      // time and not a prediction of pipelined/presented application FPS.
      await viewer.renderSingleFrame();
      if (i >= 0) {
        total.add(elapsed.elapsedMicroseconds / 1000);
        update.add(updateUs / 1000);
      }
    }
    final result = <String, Object?>{
      'case': spec.$1,
      'quality': spec.$2.toJson(),
      'disabled_effect': spec.$3?.name,
      'batched_updates': spec.$4,
      'visible_fur_shells': scene.visibleFurShells,
      'animated_materials': scene.animatedMaterialCount,
      'serialized_frame_ms': total.summary(),
      'effect_update_ms': update.summary(),
    };
    results.add(result);
    print(
        '${spec.$1}: mean ${total.summary()['mean_ms']!.toStringAsFixed(2)} ms, '
        'p95 ${total.summary()['p95_ms']!.toStringAsFixed(2)} ms, '
        'updates ${update.summary()['mean_ms']!.toStringAsFixed(2)} ms');
    if (args.contains('--capture')) {
      await scene.setShot(ShowcaseShot.overview);
      await scene.update(3.2);
      final bytes = await capture();
      final png = await pixelBufferToPng(bytes, width, height,
          hasAlpha: true, isFloat: true, linearToSrgb: true);
      await File('${output.parent.path}/showcase_${spec.$1}.png')
          .writeAsBytes(png);
    }
  }
  final checks = <String, double>{};
  if (args.contains('--verify')) {
    // Image comparisons stay outside timed runs and disable frame-varying
    // post-process dither. Failed checks terminate with a nonzero exit code.
    await viewer.view.setDithering(false);
    await scene.setQuality(ShowcaseQuality.balanced);
    for (final effect in ShowcaseEffect.values) {
      await scene.setEnabled(effect, true);
    }
    await scene.setShot(ShowcaseShot.overview);
    scene.batchUpdates = true;
    await scene.update(3.2);
    final baseline = await capture();
    void compare(Uint8List a, Uint8List b, String label,
        {required bool changes}) {
      final av = Float32List.view(a.buffer, a.offsetInBytes, a.length ~/ 4);
      final bv = Float32List.view(b.buffer, b.offsetInBytes, b.length ~/ 4);
      var sum = 0.0;
      for (var i = 0; i < av.length; i++) {
        if (i % 4 != 3) sum += (av[i] - bv[i]).abs();
      }
      final difference = sum / (av.length * .75);
      checks[label] = difference;
      if (changes ? difference < .000001 : difference > .00001) {
        throw StateError('$label: unexpected image difference $difference');
      }
      print('PASS $label (MAE $difference)');
    }

    compare(baseline, await capture(), 'paused_time', changes: false);
    await scene.update(13.2);
    compare(baseline, await capture(), 'animation', changes: true);
    scene.batchUpdates = false;
    await scene.update(3.2);
    compare(baseline, await capture(), 'batch_equivalence', changes: false);
    scene.batchUpdates = true;
    for (final effect in ShowcaseEffect.values) {
      await scene.setEnabled(effect, false);
      await scene.update(3.2);
      compare(baseline, await capture(), 'disable_${effect.name}',
          changes: true);
      await scene.setEnabled(effect, true);
      await scene.update(3.2);
      compare(baseline, await capture(), 'restore_${effect.name}',
          changes: false);
    }
    for (final quality in ShowcaseQuality.values) {
      await scene.setQuality(quality);
      if (scene.visibleFurShells != quality.furShells) {
        throw StateError('Incorrect visible fur shell count');
      }
      await scene.update(3.2);
      await capture();
    }
    for (final effect in ShowcaseEffect.values) {
      await scene.setEnabled(effect, false);
    }
    if (scene.animatedMaterialCount != 0 || scene.visibleFurShells != 0) {
      throw StateError('Disabled effects still have animated materials');
    }
    final disabled = await capture();
    await scene.update(23.2);
    compare(disabled, await capture(), 'all_disabled', changes: false);
  }
  await output.writeAsString(const JsonEncoder.withIndent('  ').convert({
    'schema': 1,
    'scene': 'storm_observatory',
    'runner': 'native_headless',
    'recorded_at': DateTime.now().toUtc().toIso8601String(),
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'dart': Platform.version,
    'backend_requested': backendName,
    'width': width,
    'height': height,
    'frames_per_case': frames,
    'warmup_frames': warmup,
    'camera_path_seconds': 20,
    'method':
        'Serialized wall-clock frame time including scene updates, native submission and GPU completion. No pixel readback or PNG encoding in timed region. Not GPU timestamps or presented FPS.',
    'resolution_note':
        'All presets use the same requested framebuffer size; Flutter resolution scaling is deliberately excluded.',
    'results': results,
    if (args.contains('--verify')) 'verification_mae': checks,
  }));
  print('Saved ${output.path}');
  await stdout.flush();
  exit(0);
}
