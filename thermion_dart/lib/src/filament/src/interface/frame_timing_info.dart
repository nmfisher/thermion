/// Timing for one frame the renderer has processed, as reported by
/// Filament's `Renderer::getFrameInfoHistory`.
///
/// Times are nanoseconds on the native steady clock, the same time base as
/// the frame scheduler's frame timestamps. A field is null when the backend
/// does not report it or has not reported it yet.
class FrameTimingInfo {
  /// Filament's sentinel for a value the backend does not support.
  static const _unsupported = -1;

  /// Filament's sentinel for a value the backend has not reported yet.
  static const _pending = -2;

  /// Monotonically increasing frame identifier.
  final int frameId;

  /// Time the GPU spent on this frame.
  final int? gpuFrameDurationInNanos;

  /// [gpuFrameDurationInNanos] after Filament's noise filtering.
  final int? denoisedGpuFrameDurationInNanos;

  /// When `Renderer::beginFrame` ran for this frame.
  final int? beginFrameInNanos;

  /// When `Renderer::endFrame` ran for this frame.
  final int? endFrameInNanos;

  /// When the backend thread started processing this frame.
  final int? backendBeginFrameInNanos;

  /// When the backend thread finished processing this frame.
  final int? backendEndFrameInNanos;

  /// When the GPU finished this frame.
  final int? gpuFrameCompleteInNanos;

  const FrameTimingInfo({
    required this.frameId,
    this.gpuFrameDurationInNanos,
    this.denoisedGpuFrameDurationInNanos,
    this.beginFrameInNanos,
    this.endFrameInNanos,
    this.backendBeginFrameInNanos,
    this.backendEndFrameInNanos,
    this.gpuFrameCompleteInNanos,
  });

  /// Maps the raw values of one Filament `FrameInfo` record, replacing its
  /// unsupported and pending sentinels with null. Filament reports a zero
  /// [gpuFrameComplete] when the backend does not record it.
  factory FrameTimingInfo.fromNative({
    required int frameId,
    required int gpuFrameDuration,
    required int denoisedGpuFrameDuration,
    required int beginFrame,
    required int endFrame,
    required int backendBeginFrame,
    required int backendEndFrame,
    required int gpuFrameComplete,
  }) {
    return FrameTimingInfo(
      frameId: frameId,
      gpuFrameDurationInNanos: _reported(gpuFrameDuration),
      denoisedGpuFrameDurationInNanos: _reported(denoisedGpuFrameDuration),
      beginFrameInNanos: _reported(beginFrame),
      endFrameInNanos: _reported(endFrame),
      backendBeginFrameInNanos: _reported(backendBeginFrame),
      backendEndFrameInNanos: _reported(backendEndFrame),
      gpuFrameCompleteInNanos: gpuFrameComplete == 0 ? null : _reported(gpuFrameComplete),
    );
  }

  static int? _reported(int value) => value == _unsupported || value == _pending ? null : value;

  @override
  String toString() =>
      'FrameTimingInfo(frameId: $frameId, gpuFrameDurationInNanos: $gpuFrameDurationInNanos, '
      'denoisedGpuFrameDurationInNanos: $denoisedGpuFrameDurationInNanos, '
      'beginFrameInNanos: $beginFrameInNanos, endFrameInNanos: $endFrameInNanos, '
      'backendBeginFrameInNanos: $backendBeginFrameInNanos, backendEndFrameInNanos: $backendEndFrameInNanos, '
      'gpuFrameCompleteInNanos: $gpuFrameCompleteInNanos)';
}
