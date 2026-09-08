import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/native_matrix4.dart';
import 'src/test_io.dart';

// Run before and after the C++ change with the same Dart fixture. This measures
// submission, callback completion, and a CPU render cycle; it is not a display
// presentation or GPU fence benchmark. Each cycle waits before reusing inputs.
Future<void> main(List<String> args) async {
  try {
    await runBenchmark(args);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exit(1);
  }
  // The process-wide NativeCallable listener keeps an idle CLI isolate alive.
  // Exit only after runBenchmark has awaited resource and engine destruction.
  exit(0);
}

Future<void> runBenchmark(List<String> args) async {
  if (args.length != 2) throw ArgumentError('Expected revision label and output JSON path');
  await initTestBindings();
  await FFIFilamentApp.create(
    config: FFIFilamentConfig(backend: defaultTestBackend, loadResource: loadResourceBytes),
  );
  final app = FilamentApp.instance!;
  try {
    final results = <String, Object>{};
    for (final count in [256, 1024]) {
      results['$count'] = await measure(app, count);
    }
    await File(args[1]).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'revision': args[0],
        'sdk': Platform.version,
        'backend': defaultTestBackend.toString(),
        'warmup_cycles_per_path': 30,
        'measured_cycles_per_path': 150,
        'results': results,
      }),
    );
  } finally {
    await app.destroy();
  }
}

Future<Map<String, Object>> measure(FilamentApp app, int count) async {
  final tm = app.transformManager as FFITransformManager;
  final entities = <ThermionEntity>[];
  final nativeInputs = <NativeMatrix4>[];
  final snapshots = <Matrix4>[];
  final swapChain = await app.createHeadlessSwapChain(256, 256);
  final view = await app.createView();
  final scene = await app.createScene();
  final camera = await app.createCamera();
  final cube = await app.createGeometry(GeometryUtils.cube());
  try {
    await scene.add(cube);
    await camera.lookAt(Vector3(0, 0, 5), focus: Vector3.zero());
    await camera.setProjectionFromVerticalFieldOfView(45, 0.1, 100, 1);
    await view.setCamera(camera);
    await view.setScene(scene);
    await view.setViewport(256, 256);
    await app.renderManager.attach(view, swapChain);
    for (var i = 0; i < count; i++) {
      entities.add(await app.createEntity());
      nativeInputs.add(NativeMatrix4.identity());
      snapshots.add(Matrix4.identity());
    }
    final samples = <String, List<List<double>>>{'snapshot': [], 'native': []};
    final order = ['snapshot', 'native'];
    final random = Random(305);
    for (var cycle = 0; cycle < 180; cycle++) {
      order.shuffle(random);
      for (final path in order) {
        // Prepare equivalent values outside timing. Native owners are reused
        // only after all callbacks from the preceding cycle have completed.
        for (var i = 0; i < count; i++) {
          snapshots[i].setTranslationRaw(i + cycle * 0.25, -i.toDouble(), 3);
          nativeInputs[i].matrix.setFrom(snapshots[i]);
        }
        final pending = <Future>[];
        final timer = Stopwatch()..start();
        for (var i = 0; i < count; i++) {
          pending.add(
            path == 'snapshot'
                ? tm.setTransformAsync(entities[i], snapshots[i])
                : tm.setTransformNativeAsync(entities[i], nativeInputs[i]),
          );
        }
        final submissionMs = timer.elapsedTicks * 1000 / timer.frequency;
        await Future.wait(pending);
        final completionMs = timer.elapsedTicks * 1000 / timer.frequency;
        await app.render();
        timer.stop();
        if (cycle >= 30) {
          samples[path]!.add([submissionMs, completionMs, timer.elapsedTicks * 1000 / timer.frequency]);
        }
        // Verify all transforms outside timing, including every snapshot and
        // native batch. Missing callbacks fail to finish instead of scoring fast.
        for (var i = 0; i < count; i++) {
          final actual = tm.getLocalTransform(entities[i]);
          for (var j = 0; j < 16; j++) {
            if (actual.storage[j] != snapshots[i].storage[j]) {
              throw StateError('$path cycle $cycle entity $i element $j mismatch');
            }
          }
        }
      }
    }
    return {
      for (final entry in samples.entries)
        entry.key: {
          'columns_ms': ['submission', 'completion', 'cpu_render_cycle'],
          'summary_ms': {
            for (var column = 0; column < 3; column++)
              ['submission', 'completion', 'cpu_render_cycle'][column]: summarize(
                entry.value.map((row) => row[column]).toList(),
              ),
          },
          'samples_ms': entry.value,
        },
    };
  } finally {
    await app.renderManager.detach(view);
    await view.setScene(null);
    await view.setCamera(null);
    await scene.remove(cube);
    await app.destroyAsset(cube);
    for (final input in nativeInputs) {
      input.dispose();
    }
    for (final entity in entities) {
      await app.destroyEntity(entity);
    }
    await camera.destroy();
    await app.destroyView(view);
    await app.destroyScene(scene);
    await app.destroySwapChain(swapChain);
  }
}

Map<String, double> summarize(List<double> values) {
  values.sort();
  double percentile(double p) => values[(p * values.length).ceil() - 1];
  return {'p50': percentile(0.50), 'p95': percentile(0.95), 'p99': percentile(0.99)};
}
