// Manual success-path benchmark. Compile this identical file in the PR and its
// base checkout with `dart build cli`; do not compare debug/JIT timings.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:thermion_dart/src/bindings/src/ffi.dart';

Future<Map<String, Object>> measure(String name, Future<void> Function() operation, int concurrency, int count) async {
  Future<void> batch(int size) async {
    if (size == 1) {
      await operation();
    } else {
      await Future.wait(List.generate(size, (_) => operation()));
    }
  }

  for (var i = 0; i < 2048; i += concurrency) {
    await batch(concurrency);
  }
  final clock = Stopwatch()..start();
  final latency = <int>[];
  Future<void> timed() async {
    final start = clock.elapsedTicks;
    await operation();
    latency.add(clock.elapsedTicks - start);
  }

  // Fixed-size batches bound the queue and the number of live callbacks.
  for (var i = 0; i < count; i += concurrency) {
    if (concurrency == 1) {
      await timed();
    } else {
      await Future.wait(List.generate(concurrency, (_) => timed()));
    }
  }
  clock.stop();
  latency.sort();
  double percentile(double p) => latency[((latency.length - 1) * p).round()] * 1e6 / clock.frequency;
  return {
    'scenario': name,
    'concurrency': concurrency,
    'count': latency.length,
    'elapsed_us': clock.elapsedTicks * 1e6 / clock.frequency,
    'ns_per_op': clock.elapsedTicks * 1e9 / clock.frequency / latency.length,
    'p50_us': percentile(.50),
    'p95_us': percentile(.95),
    'p99_us': percentile(.99),
  };
}

Future<void> main(List<String> args) async {
  final count = args.isEmpty ? 32768 : int.parse(args.first);
  if (count % 32 != 0) throw ArgumentError('Count must be divisible by 32');
  final thread = RenderThread_create();
  final engine = await withPointerCallback<TEngine>(
    (cb) => Engine_createRenderThread(TBackend.BACKEND_METAL, nullptr, nullptr, 1, false, cb),
  );
  if (engine == nullptr) throw StateError("Engine creation failed");
  final entities = Engine_getEntityManager(engine);
  final transforms = Engine_getTransformManager(engine);
  final entity = await withIntCallback((cb) => EntityManager_createEntityRenderThread(entities, cb));
  await withVoidCallback((id, cb) => TransformManager_createComponentRenderThread(transforms, entity, id, cb));
  final matrix = calloc<Double>(16);
  for (final i in [0, 5, 10, 15]) {
    matrix[i] = 1;
  }
  final image = await withPointerCallback<TLinearImage>((cb) => Image_createEmptyRenderThread(1, 1, 4, cb));
  final renderer = await withPointerCallback<TRenderer>((cb) => Engine_createRendererRenderThread(engine, cb));
  final manager = RenderManager_create(engine, renderer);
  final frameClock = Stopwatch()..start();
  final scenarios = <String, Future<void> Function()>{
    // This isolates Dart tracking and FFI listener delivery; no worker is used.
    'immediate_void': () => withVoidCallback((id, cb) => cb.asFunction<void Function(int)>()(id)),
    'image_width': () async {
      final width = await withUInt32Callback((cb) => Image_getWidthRenderThread(image, cb));
      if (width != 1) throw StateError('Unexpected image width: $width');
    },
    // This wrapper used packaged_task on the base and detached tasks on the PR.
    'set_parent': () =>
        withVoidCallback((id, cb) => TransformManager_setParentRenderThread(transforms, entity, 0, false, id, cb)),
    // These two wrappers already used detached tasks on the base.
    'set_transform': () => withVoidCallback(
      (id, cb) => TransformManager_setTransformFromBufferRenderThread(transforms, entity, matrix, id, cb),
    ),
    'render_empty': () => withVoidCallback(
      (id, cb) => RenderManager_renderRenderThread(manager, frameClock.elapsedMicroseconds * 1000, id, cb),
    ),
  };
  final results = <Map<String, Object>>[];
  try {
    for (final scenario in scenarios.entries) {
      for (final concurrency in [1, 32]) {
        results.add(await measure(scenario.key, scenario.value, concurrency, count));
      }
    }
  } finally {
    RenderManager_destroy(manager);
    await withVoidCallback((id, cb) => Engine_destroyRendererRenderThread(engine, renderer, id, cb));
    await withVoidCallback((id, cb) => Image_destroyRenderThread(image, id, cb));
    await withVoidCallback((id, cb) => TransformManager_removeComponentRenderThread(transforms, entity, id, cb));
    await withVoidCallback((id, cb) => EntityManager_destroyEntityRenderThread(entities, entity, id, cb));
    calloc.free(matrix);
    await withVoidCallback((id, cb) => Engine_destroyRenderThread(engine, id, cb));
    RenderThread_destroy(thread);
  }
  print(jsonEncode({'dart': Platform.version, 'results': results}));
  // The base's shared void listener otherwise keeps the process alive. All work
  // has completed and the native worker has joined before either version exits.
  exit(0);
}
