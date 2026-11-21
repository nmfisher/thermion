@TestOn('js')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:async';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/src/js_interop.dart' as js;
import 'package:thermion_dart/src/bindings/heap_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_surface_orientation.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/interface/surface_orientation.dart';

class _App implements FFIFilamentApp {
  @override
  Pointer<TJobThread> get jobThreadHandle => Pointer<TJobThread>.fromAddress(3);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  var heap = Uint8List(64 * 1024 * 1024);
  final allocations = <int, int>{};
  final callbacks = <int, JSFunction>{};
  final module = JSObject();
  var nextAddress = 16;
  var nextCallback = 0;
  var autoComplete = true;
  var failDispatch = false;
  void Function()? pending;
  var uploadAddress = 0;
  var uploadLength = 0;
  var uploadOffset = 0;
  var allocationCount = 0;
  int? failAllocationAt;
  int? growOnAllocation;
  void growHeap() {
    heap = Uint8List(heap.length + 64 * 1024)..setAll(0, heap);
    module.setProperty('HEAPU8'.toJS, heap.toJS);
  }

  void export(String name, JSFunction function) => module.setProperty(name.toJS, function);

  setUpAll(() {
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    export(
      '_malloc',
      ((int size) {
        allocationCount++;
        if (allocationCount == failAllocationAt) return 0;
        if (allocationCount == growOnAllocation) growHeap();
        final address = nextAddress;
        nextAddress += (size + 7) & ~7;
        allocations[address] = size;
        return address;
      }).toJS,
    );
    export(
      '_free',
      ((int address) {
        final size = allocations.remove(address)!;
        // Overwrite released storage so tests cannot use it after release.
        heap.fillRange(address, address + size, 0xcc);
      }).toJS,
    );
    int stackAlloc(int size) => throw StateError('Wasm stack allocation: $size');
    export('stackAlloc', stackAlloc.toJS);
    export('stackSave', (() => 0).toJS);
    export('stackRestore', ((int address) {}).toJS);
    export(
      'addFunction',
      ((JSFunction callback, JSString signature) {
        callbacks[++nextCallback] = callback;
        return nextCallback;
      }).toJS,
    );
    export(
      'removeFunction',
      ((int address) {
        callbacks.remove(address);
      }).toJS,
    );
    void rejectPolling() => throw StateError('Upload completions must not require Dart polling');
    export('_execute_queue', rejectPolling.toJS);
    void upload(int address, int size, int offset, int request, int callback) {
      if (failDispatch) throw StateError('upload dispatch failed');
      uploadAddress = address;
      uploadLength = size;
      uploadOffset = offset;
      void complete() => callbacks[callback]!.callAsFunction(null, request.toJS);
      if (autoComplete) {
        scheduleMicrotask(complete);
      } else {
        pending = complete;
      }
    }

    export(
      '_VertexBuffer_setBufferAtJobThread',
      ((
            int jobThread,
            int engine,
            int buffer,
            int index,
            int address,
            int size,
            int offset,
            int request,
            int callback,
          ) {
            expect(jobThread, 3);
            upload(address, size, offset, request, callback);
          })
          .toJS,
    );
    export(
      '_IndexBuffer_setBufferJobThread',
      ((int jobThread, int engine, int buffer, int address, int size, int offset, int request, int callback) {
        expect(jobThread, 3);
        upload(address, size, offset, request, callback);
      }).toJS,
    );
    export(
      '_SurfaceOrientation_build',
      ((
            int count,
            int normals,
            int normalLength,
            int normalStride,
            int tangents,
            int tangentLength,
            int tangentStride,
            int uvs,
            int uvLength,
            int uvStride,
            int positions,
            int positionLength,
            int positionStride,
            int triangleCount,
            int triangles32,
            int triangleLength32,
            int triangles16,
            int triangleLength16,
          ) {
            expect(count, 300000);
            expect(heap.buffer.asFloat32List(normals, normalLength).first, 7);
            expect(heap.buffer.asFloat32List(positions, positionLength).last, 3);
            expect(heap.buffer.asUint32List(triangles32, triangleLength32).last, 2);
            return 42;
          })
          .toJS,
    );
    export(
      '_SurfaceOrientation_getQuats_float4',
      ((int ptr, int output, int count, int stride) {
        heap.buffer.asFloat32List(output, count * 4).fillRange(0, count * 4, 1);
      }).toJS,
    );
    export(
      '_SurfaceOrientation_getQuats_short4',
      ((int ptr, int output, int count, int stride) {
        heap.buffer.asInt16List(output, count * 4).fillRange(0, count * 4, -7);
      }).toJS,
    );
    export(
      '_SurfaceOrientation_getQuats_half4',
      ((int ptr, int output, int count, int stride) {
        heap.buffer.asUint16List(output, count * 4).fillRange(0, count * 4, 0x3c00);
      }).toJS,
    );
    export('_SceneAsset_getEntity', ((int asset) => 1).toJS);
    export(
      '_SceneAsset_createInstanceJobThread',
      ((int jobThread, int asset, int materials, int count, int callback) {
        expect(jobThread, 3);
        expect(heap.buffer.asInt32List(materials, count), [12, 34]);
        callbacks[callback]!.callAsFunction(null, 99.toJS);
      }).toJS,
    );
    js.NativeLibrary.instance = module as js.NativeLibrary;
  });

  setUp(() {
    expect(allocations, isEmpty);
    nextAddress = 16;
    pending = null;
    autoComplete = true;
    failDispatch = false;
    allocationCount = 0;
    failAllocationAt = null;
    growOnAllocation = null;
  });
  tearDown(() => expect(allocations, isEmpty));

  test('large persistent dummy attributes do not borrow the Wasm stack', () async {
    const count = 450000; // Dummy attributes together exceed a 10 MiB stack.
    final geometry = Geometry(Float32List(count * 3), [0, 1, 2]);
    await Future<void>.delayed(Duration.zero);
    expect(geometry.colors.length, count * 4);
    expect(geometry.colors.first, 1);
    expect(geometry.colors.last, 1);
    expect(geometry.uvs1.length, count * 2);
    expect(geometry.uvs1.last, 0);
  });

  for (final vertex in [true, false]) {
    test('${vertex ? "vertex" : "index"} upload retains a scoped copy of a large subview', () async {
      final source = Uint32List(300002)..fillRange(0, 300002, 123);
      final data = Uint32List.sublistView(source, 1, source.length - 1);
      autoComplete = false;
      final operation = vertex
          ? FFIVertexBuffer.callerOwned(
              Pointer<TVertexBuffer>.fromAddress(1),
              Pointer<TEngine>.fromAddress(2),
              Pointer<TJobThread>.fromAddress(3),
              storageMode: VertexBufferStorageMode.direct,
            ).setBufferAt(0, data, byteOffset: 8)
          : FFIIndexBuffer(
              Pointer<TIndexBuffer>.fromAddress(1),
              Pointer<TEngine>.fromAddress(2),
              Pointer<TJobThread>.fromAddress(3),
            ).setBuffer(data, byteOffset: 8);
      expect(uploadLength, data.lengthInBytes);
      expect(uploadOffset, 8);
      expect(allocations, hasLength(1));
      data[0] = 999;
      expect(heap.buffer.asUint32List(uploadAddress, data.length).first, 123);
      expect(heap.buffer.asUint32List(uploadAddress, data.length).last, 123);
      autoComplete = true;
      final complete = pending!;
      pending = null;
      complete();
      await operation;
    });
  }

  test('failed upload dispatch releases its scoped allocation', () async {
    failDispatch = true;
    await expectLater(
      FFIIndexBuffer(
        Pointer<TIndexBuffer>.fromAddress(1),
        Pointer<TEngine>.fromAddress(2),
        Pointer<TJobThread>.fromAddress(3),
      ).setBuffer(Uint16List(3)),
      throwsStateError,
    );
  });

  test('large surface inputs are retained until build and released after the synchronous borrow', () async {
    final normals = Float32List(900000);
    final positions = Float32List(900000)..last = 3;
    final builder = FFISurfaceOrientationBuilder()
      ..vertexCount(300000)
      ..normals(normals)
      ..positions(positions)
      ..uvs(Float32List(600000))
      ..triangleCount(1)
      ..trianglesUint32(Uint32List.fromList([0, 1, 2]));
    await Future<void>.delayed(Duration.zero);
    normals[0] = 7;
    final build = builder.build();
    await expectLater(builder.build(), throwsStateError);
    await build;
  });

  for (final format in QuaternionFormat.values) {
    test('$format results survive release of the temporary Wasm allocation', () async {
      final output = await FFISurfaceOrientation(Pointer<TSurfaceOrientation>.fromAddress(42)).getQuats(format, 300000);
      final List<num> values = switch (format) {
        QuaternionFormat.FLOAT4 => output as Float32List,
        QuaternionFormat.SHORT4 => output as Int16List,
        QuaternionFormat.HALF4 => output as Uint16List,
      };
      final expected = switch (format) {
        QuaternionFormat.FLOAT4 => 1,
        QuaternionFormat.SHORT4 => -7,
        QuaternionFormat.HALF4 => 0x3c00,
      };
      expect(values.length, 1200000);
      expect(values.first, expected);
      expect(values.last, expected);
    });
  }

  test('instance material handles release their temporary allocation', () async {
    final app = _App();
    final asset = FFIAsset(Pointer<TSceneAsset>.fromAddress(1), app: app);
    await asset.createInstance(
      materialInstances: [
        FFIMaterialInstance(Pointer<TMaterialInstance>.fromAddress(12), app),
        FFIMaterialInstance(Pointer<TMaterialInstance>.fromAddress(34), app),
      ],
    );
  });

  test('scope waits for asynchronous completion before releasing storage', () async {
    final completion = Completer<int>();
    final operation = Uint8List.fromList([1, 2, 3, 4]).pass((bytes) {
      expect(bytes, [1, 2, 3, 4]);
      return completion.future;
    });
    expect(allocations, hasLength(1));
    completion.complete(42);
    expect(await operation, 42);
    expect(allocations, isEmpty);
  });

  test('scope releases storage when the callback throws', () async {
    final error = StateError('callback failed');
    await expectLater(Uint8List(4).pass<void>((bytes) => throw error), throwsA(same(error)));
  });

  test('scope releases storage when the callback future fails', () async {
    final completion = Completer<void>();
    final error = StateError('callback future failed');
    final operation = Uint8List(4).pass<void>((bytes) => completion.future);
    expect(allocations, hasLength(1));
    final failure = expectLater(operation, throwsA(same(error)));
    completion.completeError(error);
    await failure;
  });

  test('batch views use the current heap after a later allocation grows memory', () async {
    growOnAllocation = 2;
    await [
      Uint8List.fromList([1, 2]),
      Uint8List.fromList([3, 4]),
    ].pass<void>((bytes) {
      expect(bytes[0], [1, 2]);
      expect(bytes[1], [3, 4]);
      bytes[0][0] = 9;
      expect(heap[allocations.keys.first], 9);
    });
  });

  test('batch allocation failure releases earlier inputs without calling the callback', () async {
    failAllocationAt = 2;
    var called = false;
    await expectLater(
      [Uint8List(4), Uint8List(4)].pass<void>((bytes) {
        called = true;
      }),
      throwsStateError,
    );
    expect(called, isFalse);
  });

  test('batch storage is held until the callback future fails', () async {
    final error = StateError('batch callback failed');
    await expectLater(
      [Uint8List(4), Uint8List(4)].pass<void>((bytes) async {
        await Future<void>.delayed(Duration.zero);
        expect(allocations, hasLength(2));
        throw error;
      }),
      throwsA(same(error)),
    );
  });

  test('output is copied back after asynchronous completion and heap growth', () async {
    final target = Uint16List.fromList([99, 0, 0, 99]);
    final output = Uint16List.sublistView(target, 1, 3);
    final completion = Completer<int>();
    final operation = output.passOutput<int>((bytes) {
      bytes.buffer.asUint16List(bytes.offsetInBytes, 2).setAll(0, [7, 8]);
      return completion.future;
    });
    expect(target, [99, 0, 0, 99]);
    expect(allocations, hasLength(1));
    growHeap();
    completion.complete(17);
    expect(await operation, 17);
    expect(target, [99, 7, 8, 99]);
    expect(allocations, isEmpty);
  });

  test('output storage is released when the callback future fails', () async {
    final error = StateError('output callback failed');
    await expectLater(
      Uint8List(4).passOutput<void>((bytes) async {
        bytes[0] = 9;
        await Future<void>.delayed(Duration.zero);
        expect(allocations, hasLength(1));
        throw error;
      }),
      throwsA(same(error)),
    );
  });
}
