import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/matrix_buffers.dart' as buffers;
import 'package:thermion_dart/src/utils/src/matrix.dart';

void sameMatrix(Matrix4 actual, Matrix4 expected, String label, {double tolerance = 1e-6}) {
  for (var i = 0; i < 16; i++) {
    if (actual.storage[i] != expected.storage[i] && !((actual.storage[i] - expected.storage[i]).abs() <= tolerance)) {
      throw StateError('$label [$i]: ${actual.storage[i]} != ${expected.storage[i]}');
    }
  }
}

// Shared by the VM test and the full-module browser fixture.
Future<void> checkMatrixBuffers() async {
  final app = FilamentApp.instance!;
  final tm = app.transformManager;
  final parent = await app.createEntity();
  final child = await app.createEntity();
  final missing = await app.createEntity(createTransformComponent: false);
  final camera = await app.createCamera();
  try {
    final backing = Float64List(20)..fillRange(0, 20, -9876);
    final input = Matrix4.fromFloat64List(Float64List.sublistView(backing, 2, 18))
      ..setFrom(Matrix4.translation(Vector3(7.25, -2.5, 3.75)) * Matrix4.rotationZ(0.37));
    final expected = input.clone();
    tm.setTransform(child, input);
    input.setZero();
    sameMatrix(tm.getLocalTransform(child), expected, 'borrowed setter snapshot');
    if (backing.first != -9876 || backing.last != -9876) throw StateError('Input overrun');

    final outputBacking = Float64List(20)..fillRange(0, 20, -1234);
    final out = Matrix4.fromFloat64List(Float64List.sublistView(outputBacking, 2, 18));
    tm.getLocalTransformInto(child, out);
    sameMatrix(out, expected, 'offset output');
    if (outputBacking.take(2).any((v) => v != -1234) || outputBacking.skip(18).any((v) => v != -1234)) {
      throw StateError('Output overrun');
    }
    final snapshot = tm.getLocalTransform(child);
    final parentMatrix = Matrix4.translation(Vector3(10, 20, 30));
    tm.setTransform(parent, parentMatrix);
    await tm.setParent(child, parent);
    tm.getWorldTransformInto(child, out);
    sameMatrix(out, parentMatrix * expected, 'world transform');
    sameMatrix(snapshot, expected, 'getter snapshot remains independent');
    tm.getLocalTransformInto(missing, out);
    sameMatrix(out, Matrix4.zero(), 'missing local component');
    tm.getWorldTransformInto(missing, out);
    sameMatrix(out, Matrix4.zero(), 'missing world component');

    // Reuse one input across outstanding submissions; each entity must receive
    // the values present at submission, even if the render thread runs later.
    final entities = <ThermionEntity>[];
    final pending = <Future>[];
    for (var i = 0; i < 32; i++) {
      entities.add(await app.createEntity());
    }
    for (var i = 0; i < entities.length; i++) {
      input.setFrom(Matrix4.translation(Vector3(i + 0.25, -i.toDouble(), 3)));
      pending.add(tm.setTransformAsync(entities[i], input));
    }
    input.setZero();
    await Future.wait(pending);
    for (var i = 0; i < entities.length; i++) {
      sameMatrix(
        tm.getLocalTransform(entities[i]),
        Matrix4.translation(Vector3(i + 0.25, -i.toDouble(), 3)),
        'queued snapshot $i',
      );
      await app.destroyEntity(entities[i]);
    }

    await camera.setModelMatrix(expected);
    await camera.getModelMatrixInto(out);
    sameMatrix(out, expected, 'camera model');
    await camera.getViewMatrixInto(out);
    sameMatrix(out, Matrix4.inverted(expected), 'camera view');
    // Projection matrices are stored in double precision by Filament.
    final projection = Matrix4.identity();
    for (var i = 0; i < 16; i++) {
      projection.storage[i] = i + 0.123456789012345;
    }
    await camera.setProjectionMatrixWithCulling(projection, 0.1, 1000);
    await camera.getProjectionMatrixInto(out);
    sameMatrix(out, projection, 'precise projection', tolerance: 0);
    await camera.getCullingProjectionMatrixInto(out);
    sameMatrix(out, projection, 'precise culling projection', tolerance: 0);
    final cameraSnapshot = await camera.getProjectionMatrix();
    out.setZero();
    sameMatrix(cameraSnapshot, projection, 'camera snapshot', tolerance: 0);
    sameMatrix(await camera.getCullingProjectionMatrix(), projection, 'culling snapshot', tolerance: 0);
    sameMatrix(await camera.getModelMatrix(), expected, 'model snapshot');
    sameMatrix(await camera.getViewMatrix(), Matrix4.inverted(expected), 'view snapshot');

    var rejected = false;
    try {
      buffers.writeTransform(tm.getNativeHandle() as Pointer<TTransformManager>, child, Float64List(15));
    } on ArgumentError {
      rejected = true;
    }
    if (!rejected) throw StateError('Invalid buffer length accepted');
  } finally {
    await camera.destroy();
    await app.destroyEntity(child);
    await app.destroyEntity(parent);
    await app.destroyEntity(missing);
  }
}

// Reports median microseconds per operation; it measures boundary overhead,
// not frame times. Existing ABI calls provide the struct-packing baseline.
Future<String> benchmarkMatrixBuffers() async {
  final app = FilamentApp.instance!;
  final entity = await app.createEntity();
  final tm = app.transformManager;
  final handle = tm.getNativeHandle() as Pointer<TTransformManager>;
  final input = Matrix4.translation(Vector3(1, 2, 3));
  final out = Matrix4.zero();
  var sink = 0.0;
  final cases = <String, void Function()>{
    'struct setter': () => TransformManager_setTransform(handle, entity, matrix4ToDouble4x4(input)),
    'buffer setter': () => tm.setTransform(entity, input),
    'struct getter': () {
      sink += double4x4ToMatrix4(TransformManager_getLocalTransform(handle, entity)).storage[12];
    },
    'buffer snapshot getter': () {
      sink += tm.getLocalTransform(entity).storage[12];
    },
    'buffer reuse getter': () {
      tm.getLocalTransformInto(entity, out);
      sink += out.storage[12];
    },
  };
  const count = 20000;
  final results = <String>[];
  for (final entry in cases.entries) {
    final warmupStack = FILAMENT_WASM ? stackSave() : null;
    try {
      for (var i = 0; i < 5000; i++) {
        entry.value();
      }
    } finally {
      if (warmupStack != null) stackRestore(warmupStack);
    }
    final samples = <double>[];
    for (var round = 0; round < 7; round++) {
      // Legacy web struct wrappers allocate on the WASM stack.
      final stack = FILAMENT_WASM ? stackSave() : null;
      try {
        final timer = Stopwatch()..start();
        for (var i = 0; i < count; i++) {
          entry.value();
        }
        timer.stop();
        samples.add(timer.elapsedMicroseconds / count);
      } finally {
        if (stack != null) stackRestore(stack);
      }
    }
    samples.sort();
    results.add('${entry.key}: ${samples[3].toStringAsFixed(3)} us/op');
  }
  await app.destroyEntity(entity);
  if (sink == 0) throw StateError('Benchmark produced no output');
  return results.join('\n');
}
