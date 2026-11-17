import 'dart:math' as math;

import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/filament/src/interface/frame_timing_info.dart';

/// Copies timing records on the render job thread and releases the buffer once
/// the records have been mapped to Dart objects.
Future<List<FrameTimingInfo>> getFrameInfoHistory(
  Pointer<TJobThread> jobThread,
  Pointer<TRenderer> renderer,
  int count,
) async {
  final capacity = math.min(count, Renderer_getMaxFrameHistorySize(renderer));
  final out = allocate<TFrameInfo>(sizeOf<TFrameInfo>() * capacity);
  if (out == nullptr) throw StateError('Frame history buffer allocation failed');
  try {
    final copied = await withSizeCallback(
      (callback) => Renderer_getFrameInfoHistoryJobThread(jobThread, renderer, out, capacity, callback),
    );
    return [
      for (var i = 0; i < copied; i++)
        FrameTimingInfo.fromNative(
          frameId: out[i].frameId.toUnsigned(32),
          gpuFrameDuration: _exactInt(out[i].gpuFrameDuration),
          denoisedGpuFrameDuration: _exactInt(out[i].denoisedGpuFrameDuration),
          beginFrame: _exactInt(out[i].beginFrame),
          endFrame: _exactInt(out[i].endFrame),
          backendBeginFrame: _exactInt(out[i].backendBeginFrame),
          backendEndFrame: _exactInt(out[i].backendEndFrame),
          gpuFrameComplete: _exactInt(out[i].gpuFrameComplete),
        ),
    ];
  } finally {
    free(out);
  }
}

// Native bindings expose int64 fields as int; web bindings expose BigInt.
int _exactInt(Object value) {
  if (value is int) return value;
  final integer = value as BigInt;
  final result = integer.toInt();
  if (BigInt.from(result) != integer) {
    throw RangeError('Frame timing cannot be represented exactly as a web int: $integer');
  }
  return result;
}
