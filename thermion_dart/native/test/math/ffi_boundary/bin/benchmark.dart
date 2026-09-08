import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:matrix_ffi_boundary_benchmark/bindings.g.dart';

const matrixCount = 256;
const warmupCalls = 100000;
const measuredCalls = 1000000;
const rounds = 15;

// Match the left-to-right additions in sumData. Do not construct Matrix4s,
// temporary lists, or output views inside the measured loops.
double sumStruct(double4x4 m) =>
    m.col1[0] +
    m.col1[1] +
    m.col1[2] +
    m.col1[3] +
    m.col2[0] +
    m.col2[1] +
    m.col2[2] +
    m.col2[3] +
    m.col3[0] +
    m.col3[1] +
    m.col3[2] +
    m.col3[3] +
    m.col4[0] +
    m.col4[1] +
    m.col4[2] +
    m.col4[3];

double sumData(Float64List m) =>
    m[0] + m[1] + m[2] + m[3] + m[4] + m[5] + m[6] + m[7] + m[8] + m[9] + m[10] + m[11] + m[12] + m[13] + m[14] + m[15];

double structElement(double4x4 m, int i) => switch (i ~/ 4) {
  0 => m.col1[i % 4],
  1 => m.col2[i % 4],
  2 => m.col3[i % 4],
  _ => m.col4[i % 4],
};

double expectedValue(int matrix, int element) => matrix * 16 + element + 0.25;

void requireEqual(double actual, double expected, String context) {
  if (actual != expected) {
    throw StateError('$context: expected $expected, got $actual');
  }
}

double expectedChecksum(int calls, bool allElements) {
  var result = 0.0;
  for (var i = 0; i < calls; i++) {
    final matrix = i & (matrixCount - 1);
    result += allElements ? matrix * 256 + 124 : expectedValue(matrix, 12);
  }
  return result;
}

void main(List<String> args) {
  // A mode label is supplied by the caller; Dart doesn't expose a reliable
  // runtime JIT/AOT flag. The command and SDK version are recorded with results.
  if (args.length != 1 || !['jit', 'aot'].contains(args.single)) {
    throw ArgumentError('Usage: benchmark.dart jit | benchmark aot');
  }
  final source = calloc<double4x4>(matrixCount);
  final guardedNative = calloc<Double>(18);
  try {
    final sourceData = source.cast<Double>().asTypedList(matrixCount * 16);
    for (var i = 0; i < sourceData.length; i++) {
      sourceData[i] = expectedValue(i ~/ 16, i % 16);
    }
    final nativeOutput = guardedNative + 1;
    final nativeData = nativeOutput.asTypedList(16);
    final guardedDart = Float64List(18);
    final dartData = Float64List.sublistView(guardedDart, 1, 17);
    guardedNative[0] = guardedNative[17] = -9876.5;
    guardedDart[0] = guardedDart[17] = -9876.5;

    // Validate every element and the output bounds before timing. The corpus
    // varies every call, is initialized at runtime, and fits in cache.
    for (var i = 0; i < matrixCount; i++) {
      final returned = MatrixBenchmark_getValue(source, i);
      MatrixBenchmark_getInto(source, i, nativeOutput);
      MatrixBenchmark_getInto(source, i, dartData.address);
      for (var j = 0; j < 16; j++) {
        final expected = expectedValue(i, j);
        requireEqual(structElement(returned, j), expected, 'struct [$i][$j]');
        requireEqual(nativeData[j], expected, 'native [$i][$j]');
        requireEqual(dartData[j], expected, 'typed data [$i][$j]');
      }
    }

    // Each timed function owns its loop, with one foreign call per iteration.
    // There is no per-iteration closure dispatch. Output buffers/views are
    // reused; allocations required by Dart's struct-return ABI remain measured.
    final cases = <String, double Function(int)>{
      'struct / one': (count) {
        var checksum = 0.0;
        for (var i = 0; i < count; i++) {
          final value = MatrixBenchmark_getValue(source, i & 255);
          checksum += value.col4[0];
        }
        return checksum;
      },
      'native pointer / one': (count) {
        var checksum = 0.0;
        for (var i = 0; i < count; i++) {
          MatrixBenchmark_getInto(source, i & 255, nativeOutput);
          checksum += nativeData[12];
        }
        return checksum;
      },
      'Dart typed data / one': (count) {
        var checksum = 0.0;
        for (var i = 0; i < count; i++) {
          MatrixBenchmark_getInto(source, i & 255, dartData.address);
          checksum += dartData[12];
        }
        return checksum;
      },
      'struct / all': (count) {
        var checksum = 0.0;
        for (var i = 0; i < count; i++) {
          checksum += sumStruct(MatrixBenchmark_getValue(source, i & 255));
        }
        return checksum;
      },
      'native pointer / all': (count) {
        var checksum = 0.0;
        for (var i = 0; i < count; i++) {
          MatrixBenchmark_getInto(source, i & 255, nativeOutput);
          checksum += sumData(nativeData);
        }
        return checksum;
      },
      'Dart typed data / all': (count) {
        var checksum = 0.0;
        for (var i = 0; i < count; i++) {
          MatrixBenchmark_getInto(source, i & 255, dartData.address);
          checksum += sumData(dartData);
        }
        return checksum;
      },
    };

    final samples = {for (final name in cases.keys) name: <double>[]};
    final expectedOne = expectedChecksum(measuredCalls, false);
    final expectedAll = expectedChecksum(measuredCalls, true);
    for (final entry in cases.entries) {
      requireEqual(entry.value(warmupCalls), expectedChecksum(warmupCalls, entry.key.endsWith('/ all')), entry.key);
    }
    final random = Random(304305);
    var sink = 0.0;
    for (var round = 0; round < rounds; round++) {
      // Interleave in a deterministic shuffled order to reduce ordering bias.
      final order = cases.keys.toList()..shuffle(random);
      for (final name in order) {
        final run = cases[name]!;
        final timer = Stopwatch()..start();
        final checksum = run(measuredCalls);
        timer.stop();
        requireEqual(checksum, name.endsWith('/ all') ? expectedAll : expectedOne, name);
        sink += checksum;
        samples[name]!.add(timer.elapsedTicks * 1e9 / timer.frequency / measuredCalls);
      }
    }
    requireEqual(guardedNative[0], -9876.5, 'native lower guard');
    requireEqual(guardedNative[17], -9876.5, 'native upper guard');
    requireEqual(guardedDart[0], -9876.5, 'Dart lower guard');
    requireEqual(guardedDart[17], -9876.5, 'Dart upper guard');

    print(
      const JsonEncoder.withIndent('  ').convert({
        'mode': args.single,
        'sdk': Platform.version,
        'os': Platform.operatingSystem,
        'abi': Abi.current().toString(),
        'warmup_calls': warmupCalls,
        'calls_per_sample': measuredCalls,
        'rounds': rounds,
        'sink': sink,
        'results': {
          for (final entry in samples.entries)
            entry.key: {'median_ns': (entry.value.toList()..sort())[rounds ~/ 2], 'samples_ns': entry.value},
        },
      }),
    );
  } finally {
    calloc.free(guardedNative);
    calloc.free(source);
  }
}
