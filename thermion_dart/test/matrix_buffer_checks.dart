import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/native_matrix4.dart';
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
  final internalTm = tm as FFITransformManager;
  final parent = await app.createEntity();
  final child = await app.createEntity();
  final missing = await app.createEntity(createTransformComponent: false);
  final camera = await app.createCamera();
  final internalCamera = camera as FFICamera;
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
    internalTm.getLocalTransformInto(child, out);
    sameMatrix(out, expected, 'offset output');
    if (outputBacking.take(2).any((v) => v != -1234) || outputBacking.skip(18).any((v) => v != -1234)) {
      throw StateError('Output overrun');
    }
    final snapshot = tm.getLocalTransform(child);
    final parentMatrix = Matrix4.translation(Vector3(10, 20, 30));
    tm.setTransform(parent, parentMatrix);
    await tm.setParent(child, parent);
    internalTm.getWorldTransformInto(child, out);
    sameMatrix(out, parentMatrix * expected, 'world transform');
    sameMatrix(snapshot, expected, 'getter snapshot remains independent');
    internalTm.getLocalTransformInto(missing, out);
    sameMatrix(out, Matrix4.zero(), 'missing local component');
    internalTm.getWorldTransformInto(missing, out);
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
    await internalCamera.getModelMatrixInto(out);
    sameMatrix(out, expected, 'camera model');
    await internalCamera.getViewMatrixInto(out);
    sameMatrix(out, Matrix4.inverted(expected), 'camera view');
    // Projection matrices are stored in double precision by Filament.
    final projection = Matrix4.identity();
    for (var i = 0; i < 16; i++) {
      projection.storage[i] = i + 0.123456789012345;
    }
    await camera.setProjectionMatrixWithCulling(projection, 0.1, 1000);
    await internalCamera.getProjectionMatrixInto(out);
    sameMatrix(out, projection, 'precise projection', tolerance: 0);
    await internalCamera.getCullingProjectionMatrixInto(out);
    sameMatrix(out, projection, 'precise culling projection', tolerance: 0);
    final cameraSnapshot = await camera.getProjectionMatrix();
    out.setZero();
    sameMatrix(cameraSnapshot, projection, 'camera snapshot', tolerance: 0);
    sameMatrix(await camera.getCullingProjectionMatrix(), projection, 'culling snapshot', tolerance: 0);
    sameMatrix(await camera.getModelMatrix(), expected, 'model snapshot');
    sameMatrix(await camera.getViewMatrix(), Matrix4.inverted(expected), 'view snapshot');

    var rejected = false;
    try {
      buffers.TransformManager_setTransformFromBufferTypedData(internalTm.getNativeHandle(), child, Float64List(15));
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

Future<void> checkNativeMatrices() async {
  final app = FilamentApp.instance!;
  final tm = app.transformManager;
  final internalTm = tm as FFITransformManager;
  final parent = await app.createEntity();
  final child = await app.createEntity();
  final missing = await app.createEntity(createTransformComponent: false);
  final camera = await app.createCamera();
  final internalCamera = camera as FFICamera;
  final input = NativeMatrix4.identity();
  final out = NativeMatrix4.zero();
  final parentMatrix = NativeMatrix4.copy(Matrix4.translation(Vector3(10, 20, 30)));
  final entities = <ThermionEntity>[];
  final pending = <Future<void>>[];
  try {
    final view = input.matrix;
    sameMatrix(view, Matrix4.identity(), 'native identity');
    sameMatrix(out.matrix, Matrix4.zero(), 'native zero');
    final expected = Matrix4.translation(Vector3(3.25, -7.5, 9.75)) * Matrix4.rotationZ(0.47);
    view.setFrom(expected);
    internalTm.setTransformNative(child, input);
    internalTm.getLocalTransformNativeInto(child, out);
    sameMatrix(out.matrix, expected, 'Dart writes / native reads shared storage');
    // The same previously returned Matrix4 view observes native output writes.
    view.setZero();
    internalTm.getLocalTransformNativeInto(child, input);
    sameMatrix(view, expected, 'native writes / existing Dart view reads');
    internalTm.setTransformNative(parent, parentMatrix);
    await tm.setParent(child, parent);
    internalTm.getWorldTransformNativeInto(child, out);
    sameMatrix(out.matrix, parentMatrix.matrix * expected, 'native world matrix');
    internalTm.getLocalTransformNativeInto(missing, out);
    sameMatrix(out.matrix, Matrix4.zero(), 'missing native local matrix');
    internalTm.getWorldTransformNativeInto(missing, out);
    sameMatrix(out.matrix, Matrix4.zero(), 'missing native world matrix');
    internalTm.setTransformNative(missing, input);

    await internalCamera.setModelMatrixNative(input);
    await internalCamera.getModelMatrixNativeInto(out);
    sameMatrix(out.matrix, expected, 'native camera model');
    await internalCamera.getViewMatrixNativeInto(out);
    sameMatrix(out.matrix, Matrix4.inverted(expected), 'native camera view');
    final projection = Matrix4.identity();
    for (var i = 0; i < 16; i++) {
      projection.storage[i] = i + 0.123456789012345;
    }
    view.setFrom(projection);
    await internalCamera.setProjectionMatrixWithCullingNative(input, 0.1, 1000);
    await internalCamera.getProjectionMatrixNativeInto(out);
    sameMatrix(out.matrix, projection, 'native exact projection', tolerance: 0);
    await internalCamera.getCullingProjectionMatrixNativeInto(out);
    sameMatrix(out.matrix, projection, 'native exact culling projection', tolerance: 0);

    for (var i = 0; i < 64; i++) {
      entities.add(await app.createEntity());
    }
    // Each native submission retains its C++ matrix, including if the Dart
    // owner is disposed immediately. No Dart/native buffer snapshot is needed.
    for (var i = 0; i < entities.length; i++) {
      final submitted = NativeMatrix4.copy(Matrix4.translation(Vector3(i + 0.25, 2, 3)));
      pending.add(internalTm.setTransformNativeAsync(entities[i], submitted));
      submitted.dispose();
      submitted.dispose();
      if (!submitted.isDisposed) throw StateError('Native matrix disposal failed');
    }
    await Future.wait(pending);
    for (var i = 0; i < entities.length; i++) {
      sameMatrix(
        tm.getLocalTransform(entities[i]),
        Matrix4.translation(Vector3(i + 0.25, 2, 3)),
        'retained native queue $i',
      );
    }
    // Ordinary queued setters still snapshot even when passed a native view.
    view.setFrom(expected);
    final copied = tm.setTransformAsync(child, view);
    view.setZero();
    await copied;
    sameMatrix(tm.getLocalTransform(child), expected, 'native view through snapshot API');

    out.dispose();
    var rejected = 0;
    try {
      out.matrix;
    } on StateError {
      rejected++;
    }
    try {
      internalTm.setTransformNative(child, out);
    } on StateError {
      rejected++;
    }
    try {
      await internalTm.setTransformNativeAsync(child, out);
    } on StateError {
      rejected++;
    }
    try {
      await internalCamera.setModelMatrixNative(out);
    } on StateError {
      rejected++;
    }
    if (rejected != 4) throw StateError('Disposed native matrix was accepted');
  } finally {
    await Future.wait(pending);
    input.dispose();
    out.dispose();
    parentMatrix.dispose();
    await camera.destroy();
    for (final entity in entities) {
      await app.destroyEntity(entity);
    }
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
  final internalTm = tm as FFITransformManager;
  final handle = internalTm.getNativeHandle();
  final input = Matrix4.translation(Vector3(1, 2, 3));
  final out = Matrix4.zero();
  final nativeInput = NativeMatrix4.copy(input);
  final nativeOut = NativeMatrix4.zero();
  var sink = 0.0;
  final cases = <String, void Function()>{
    'struct setter': () => TransformManager_setTransform(handle, entity, matrix4ToDouble4x4(input)),
    'buffer setter': () => tm.setTransform(entity, input),
    'native matrix setter': () => internalTm.setTransformNative(entity, nativeInput),
    'struct getter': () {
      sink += double4x4ToMatrix4(TransformManager_getLocalTransform(handle, entity)).storage[12];
    },
    'buffer snapshot getter': () {
      sink += tm.getLocalTransform(entity).storage[12];
    },
    'native matrix reuse getter': () {
      internalTm.getLocalTransformNativeInto(entity, nativeOut);
      sink += nativeOut.matrix.storage[12];
    },
    'buffer reuse getter': () {
      internalTm.getLocalTransformInto(entity, out);
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
  nativeInput.dispose();
  nativeOut.dispose();
  await app.destroyEntity(entity);
  if (sink == 0) throw StateError('Benchmark produced no output');
  return results.join('\n');
}
