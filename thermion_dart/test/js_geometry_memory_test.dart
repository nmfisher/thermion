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
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';

class _App implements FFIFilamentApp {
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
  void export(String name, JSFunction function) => module.setProperty(name.toJS, function);

  setUpAll(() {
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    export(
      '_malloc',
      ((int size) {
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
    export(
      '_execute_queue',
      (() {
        if (autoComplete) {
          final complete = pending;
          pending = null;
          complete?.call();
        }
      }).toJS,
    );
    void upload(int address, int size, int offset, int request, int callback) {
      if (failDispatch) throw StateError('upload dispatch failed');
      uploadAddress = address;
      uploadLength = size;
      uploadOffset = offset;
      pending = () => callbacks[callback]!.callAsFunction(null, request.toJS);
    }

    export(
      '_VertexBuffer_setBufferAtRenderThread',
      ((int engine, int buffer, int index, int address, int size, int offset, int request, int callback) {
        upload(address, size, offset, request, callback);
      }).toJS,
    );
    export(
      '_IndexBuffer_setBufferRenderThread',
      ((int engine, int buffer, int address, int size, int offset, int request, int callback) {
        upload(address, size, offset, request, callback);
      }).toJS,
    );
    export('_SceneAsset_getEntity', ((int asset) => 1).toJS);
    export(
      '_SceneAsset_createInstanceRenderThread',
      ((int asset, int materials, int count, int callback) {
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
  });
  tearDown(() => expect(allocations, isEmpty));

  for (final vertex in [true, false]) {
    test('${vertex ? "vertex" : "index"} upload retains a scoped copy of a large subview', () async {
      final source = Uint32List(300002)..fillRange(0, 300002, 123);
      final data = Uint32List.sublistView(source, 1, source.length - 1);
      autoComplete = false;
      final operation = vertex
          ? FFIVertexBuffer.callerOwned(
              Pointer<TVertexBuffer>.fromAddress(1),
              Pointer<TEngine>.fromAddress(2),
              storageMode: VertexBufferStorageMode.direct,
            ).setBufferAt(0, data, byteOffset: 8)
          : FFIIndexBuffer(
              Pointer<TIndexBuffer>.fromAddress(1),
              Pointer<TEngine>.fromAddress(2),
            ).setBuffer(data, byteOffset: 8);
      expect(uploadLength, data.lengthInBytes);
      expect(uploadOffset, 8);
      expect(allocations, hasLength(1));
      data[0] = 999;
      expect(heap.buffer.asUint32List(uploadAddress, data.length).first, 123);
      expect(heap.buffer.asUint32List(uploadAddress, data.length).last, 123);
      autoComplete = true;
      await operation;
    });
  }

  test('failed upload dispatch releases its scoped allocation', () async {
    failDispatch = true;
    await expectLater(
      FFIIndexBuffer(Pointer<TIndexBuffer>.fromAddress(1), Pointer<TEngine>.fromAddress(2)).setBuffer(Uint16List(3)),
      throwsStateError,
    );
  });

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
}
