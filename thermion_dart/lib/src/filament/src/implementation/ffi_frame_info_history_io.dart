import 'package:thermion_dart/thermion_dart.dart';

/// Native (dart:ffi) implementation of [FilamentApp.getFrameInfoHistory].
///
/// Filament's Renderer is not thread-safe, so the copy runs on the job
/// thread that renders frames. The records land in a buffer owned by this
/// call, which is freed once they are mapped to Dart objects.
Future<List<FrameTimingInfo>> getFrameInfoHistory(
  Pointer<TJobThread> jobThread,
  Pointer<TRenderer> renderer,
  int count,
) async {
  final out = allocate<TFrameInfo>(sizeOf<TFrameInfo>() * count);
  try {
    final copied = await withSizeCallback(
      (callback) => Renderer_getFrameInfoHistoryJobThread(jobThread, renderer, out, count, callback),
    );
    return [
      for (var i = 0; i < copied; i++)
        FrameTimingInfo.fromNative(
          frameId: out[i].frameId,
          gpuFrameDuration: out[i].gpuFrameDuration,
          denoisedGpuFrameDuration: out[i].denoisedGpuFrameDuration,
          beginFrame: out[i].beginFrame,
          endFrame: out[i].endFrame,
          backendBeginFrame: out[i].backendBeginFrame,
          backendEndFrame: out[i].backendEndFrame,
          gpuFrameComplete: out[i].gpuFrameComplete,
        ),
    ];
  } finally {
    free(out);
  }
}
