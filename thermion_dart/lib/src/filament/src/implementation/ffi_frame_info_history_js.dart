import 'dart:math' as math;

import 'package:thermion_dart/src/bindings/src/js_interop.dart';
import 'package:thermion_dart/src/filament/src/interface/frame_timing_info.dart';

/// Reads frame timing records from the Wasm heap after the render job completes.
Future<List<FrameTimingInfo>> getFrameInfoHistory(
  Pointer<TJobThread> jobThread,
  Pointer<TRenderer> renderer,
  int count,
) async {
  final capacity = math.min(count, Renderer_getMaxFrameHistorySize(renderer));
  final out = malloc<TFrameInfo>(TFrameInfo.byteSize * capacity);
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

int _exactInt(BigInt value) {
  final result = value.toInt();
  if (BigInt.from(result) != value) {
    throw RangeError('Frame timing cannot be represented exactly as a web int: $value');
  }
  return result;
}
