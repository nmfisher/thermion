@TestOn('js')
library;

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart' show FrameTimingInfo;
import 'package:thermion_dart/src/bindings/bindings.dart' as bindings;
import 'package:thermion_dart/src/bindings/src/js_interop.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_frame_info_history.dart' as history;

void main() {
  late Uint8List heap;
  late JSObject module;
  final allocations = <int, int>{};
  final callbacks = <int, JSFunction>{};
  var nextAddress = 16;
  var nextCallback = 0;
  var failAllocation = false;
  var failDispatch = false;
  var copied = 2;
  var requestedCapacity = 0;
  var gpuTime = BigInt.from(3000000);
  void Function()? complete;

  void writeInt64(ByteData data, int offset, BigInt value) {
    data.setUint32(offset, value.toUnsigned(32).toInt(), Endian.little);
    data.setUint32(offset + 4, (value >> 32).toUnsigned(32).toInt(), Endian.little);
  }

  setUp(() {
    heap = Uint8List(4096);
    module = JSObject();
    nextAddress = 16;
    nextCallback = 0;
    failAllocation = false;
    failDispatch = false;
    copied = 2;
    requestedCapacity = 0;
    gpuTime = BigInt.from(3000000);
    complete = null;
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    void export(String name, JSFunction function) => module.setProperty(name.toJS, function);
    export(
      '_malloc',
      ((int size) {
        if (failAllocation) return 0;
        final address = nextAddress;
        nextAddress += size;
        allocations[address] = size;
        return address;
      }).toJS,
    );
    export(
      '_free',
      ((int address) {
        final size = allocations.remove(address)!;
        heap.fillRange(address, address + size, 0xcc);
      }).toJS,
    );
    export(
      'addFunction',
      ((JSFunction function, JSString signature) {
        expect(signature.toDart, 'vi');
        callbacks[++nextCallback] = function;
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
      'getValue',
      ((int address, JSString type) {
        expect(type.toDart, 'i32');
        return ByteData.sublistView(heap).getInt32(address, Endian.little);
      }).toJS,
    );
    export('_Renderer_getMaxFrameHistorySize', ((int renderer) => 2).toJS);
    export(
      '_Renderer_getFrameInfoHistoryJobThread',
      ((int jobThread, int renderer, int output, int capacity, int callback) {
        if (failDispatch) throw StateError('frame history dispatch failed');
        expect(jobThread, 3);
        expect(renderer, 7);
        requestedCapacity = capacity;
        complete = () {
          final records = copied < capacity ? copied : capacity;
          final data = ByteData.sublistView(heap);
          for (var i = 0; i < records; i++) {
            final base = output + i * 64;
            data.setUint32(base, 0xfffffffe - i, Endian.little);
            writeInt64(data, base + 8, gpuTime);
            writeInt64(data, base + 16, BigInt.from(-2));
            writeInt64(data, base + 24, BigInt.from(9007199254740991));
            writeInt64(data, base + 32, BigInt.from(9007199254740991));
            writeInt64(data, base + 40, BigInt.from(-1));
            writeInt64(data, base + 48, BigInt.from(4000));
            writeInt64(data, base + 56, BigInt.zero);
          }
          callbacks[callback]!.callAsFunction(null, records.toJS);
        };
      }).toJS,
    );
    NativeLibrary.instance = module as NativeLibrary;
  });

  tearDown(() {
    expect(allocations, isEmpty);
    expect(callbacks, isEmpty);
  });

  Future<List<FrameTimingInfo>> read({int count = 2}) => history.getFrameInfoHistory(
    bindings.Pointer<bindings.TJobThread>.fromAddress(3),
    bindings.Pointer<bindings.TRenderer>.fromAddress(7),
    count,
  );

  test('keeps output alive until completion and reads a fresh heap view', () async {
    final pending = read(count: 9007199254740991);
    expect(requestedCapacity, 2);
    expect(allocations.values, [128]);
    expect(callbacks, hasLength(1));
    // A later allocation can replace the module's backing buffer.
    heap = Uint8List(8192)..setAll(0, heap);
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    complete!();
    final frames = await pending;
    expect(frames.map((frame) => frame.frameId), [0xfffffffe, 0xfffffffd]);
    expect(frames.first.gpuFrameDurationInNanos, 3000000);
    expect(frames.first.denoisedGpuFrameDurationInNanos, isNull);
    expect(frames.first.beginFrameInNanos, 9007199254740991);
    expect(frames.first.endFrameInNanos, 9007199254740991);
    expect(frames.first.backendBeginFrameInNanos, isNull);
    expect(frames.first.backendEndFrameInNanos, 4000);
    expect(frames.first.gpuFrameCompleteInNanos, isNull);
  });

  test('honors a smaller count', () async {
    final pending = read(count: 1);
    expect(requestedCapacity, 1);
    expect(allocations.values, [64]);
    complete!();
    expect(await pending, hasLength(1));
  });

  test('returns empty history', () async {
    copied = 0;
    final pending = read();
    complete!();
    expect(await pending, isEmpty);
  });

  test('cleans up after dispatch fails', () async {
    failDispatch = true;
    await expectLater(read(), throwsStateError);
  });

  test('handles allocation failure before registering a callback', () async {
    failAllocation = true;
    await expectLater(read(), throwsStateError);
    expect(complete, isNull);
  });

  test('accepts exactly representable timestamps above the safe integer range', () async {
    gpuTime = BigInt.parse('1794820916918275072');
    final pending = read();
    complete!();
    final frames = await pending;
    expect(BigInt.from(frames.first.gpuFrameDurationInNanos!), gpuTime);
  });

  for (final value in ['9007199254740993', '-9007199254740993']) {
    test('rejects inexact timing $value and releases output', () async {
      gpuTime = BigInt.parse(value);
      final pending = read();
      complete!();
      await expectLater(pending, throwsRangeError);
    });
  }

  test('generated accessors preserve the full signed 64-bit range', () {
    final output = malloc<TFrameInfo>(TFrameInfo.byteSize);
    try {
      for (final value in [
        BigInt.parse('-9223372036854775808'),
        BigInt.parse('9223372036854775807'),
        BigInt.from(-2),
        BigInt.from(-1),
        BigInt.zero,
      ]) {
        output[0].gpuFrameDuration = value;
        expect(output[0].gpuFrameDuration, value);
      }
    } finally {
      free(output);
    }
  });
}
