// Manual headless Metal benchmark: submission latency, not display presentation.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:thermion_dart/src/bindings/src/ffi.dart' show TransformManager_setTransformFromBufferRenderThread;

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

Future<void> main(List<String> args) async {
  Timer(const Duration(seconds: 60), () {
    stderr.writeln("Benchmark timed out");
    exit(2);
  });
  try {
    await run(args);
  } catch (error, stack) {
    stderr.writeln("$error\n$stack");
    exit(1);
  }
}

Future<void> run(List<String> args) async {
  final seconds = args.isEmpty ? 3 : int.parse(args.first);
  await FFIFilamentApp.create(config: FFIFilamentConfig(backend: Backend.METAL));
  print("Engine ready");
  final app = FilamentApp.instance! as FFIFilamentApp;
  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;
  print("Viewer ready");
  final swapchain = await app.createHeadlessSwapChain(512, 512);
  await app.renderManager.attach(viewer.view, swapchain);
  await viewer.view.setViewport(512, 512);
  await viewer.setPostProcessing(false);
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(near: .1, far: 100, aspect: 1, focalLength: 28);
  await camera.lookAt(Vector3(0, 2, 5));
  final material = await app.createUbershaderMaterialInstance(unlit: true);
  await material.setParameterFloat4('baseColorFactor', 1, .3, .1, 1);
  final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
  await viewer.setRendering(true);

  print("Scene ready");
  final entities = <int>[];
  for (var i = 0; i < 100; i++) {
    entities.add(await app.createEntity());
  }
  final transforms = Engine_getTransformManager(app.engine);
  final matrix = calloc<Double>(16);
  for (final i in [0, 5, 10, 15]) {
    matrix[i] = 1;
  }
  final results = <Map<String, Object>>[];
  try {
    for (final fps in [60, 120]) {
      for (final updates in [0, 100]) {
        print("Starting $fps Hz, $updates updates");
        final clock = Stopwatch()..start();
        final workUs = <double>[];
        var deadlineMisses = 0;
        final warmup = fps;
        final count = fps * seconds;
        for (var frame = 0; frame < warmup + count; frame++) {
          final due = (frame * 1000000 / fps).round();
          final wait = due - clock.elapsedMicroseconds;
          if (wait > 0) await Future<void>.delayed(Duration(microseconds: wait));
          final start = clock.elapsedTicks;
          matrix[12] = (frame % 100) / 100;
          await Future.wait([
            for (var i = 0; i < updates; i++)
              withVoidCallback(
                (id, cb) =>
                    TransformManager_setTransformFromBufferRenderThread(transforms, entities[i], matrix, id, cb),
              ),
          ]);
          await app.render();
          if (frame >= warmup) {
            workUs.add((clock.elapsedTicks - start) * 1e6 / clock.frequency);
            if (clock.elapsedMicroseconds > due + 1000000 / fps) deadlineMisses++;
          }
        }
        workUs.sort();
        double percentile(double p) => workUs[((workUs.length - 1) * p).round()];
        results.add({
          'fps': fps,
          'updates': updates,
          'frames': count,
          'p50_us': percentile(.5),
          'p95_us': percentile(.95),
          'p99_us': percentile(.99),
          'deadline_misses': deadlineMisses,
        });
      }
    }
    print("Measurements complete; flushing");
    await app.flush();
    print("Flush complete");
  } finally {
    calloc.free(matrix);
    for (final entity in entities) {
      await app.destroyEntity(entity);
    }
    print("Entities destroyed");
    await viewer.destroyAsset(cube);
    print("Cube destroyed");
    await material.destroy();
    print("Material destroyed");
    await viewer.dispose();
    print("Viewer destroyed");
    await app.destroySwapChain(swapchain);
    print("Swapchain destroyed");
    await app.destroy();
    print("App destroyed");
  }
  print(jsonEncode({'dart': Platform.version, 'results': results}));
  exit(0);
}
