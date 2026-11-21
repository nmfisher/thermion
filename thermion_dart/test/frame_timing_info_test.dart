import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() {
  group('FrameTimingInfo.fromNative', () {
    test('copies reported values', () {
      final info = FrameTimingInfo.fromNative(
        frameId: 7,
        gpuFrameDuration: 4000000,
        denoisedGpuFrameDuration: 3900000,
        beginFrame: 1000,
        endFrame: 2000,
        backendBeginFrame: 3000,
        backendEndFrame: 4000,
        gpuFrameComplete: 5000,
      );

      expect(info.frameId, 7);
      expect(info.gpuFrameDurationInNanos, 4000000);
      expect(info.denoisedGpuFrameDurationInNanos, 3900000);
      expect(info.beginFrameInNanos, 1000);
      expect(info.endFrameInNanos, 2000);
      expect(info.backendBeginFrameInNanos, 3000);
      expect(info.backendEndFrameInNanos, 4000);
      expect(info.gpuFrameCompleteInNanos, 5000);
    });

    test('maps the unsupported and pending sentinels to null', () {
      const unsupported = -1;
      const pending = -2;
      final info = FrameTimingInfo.fromNative(
        frameId: 1,
        gpuFrameDuration: unsupported,
        denoisedGpuFrameDuration: pending,
        beginFrame: unsupported,
        endFrame: pending,
        backendBeginFrame: unsupported,
        backendEndFrame: pending,
        gpuFrameComplete: unsupported,
      );

      expect(info.gpuFrameDurationInNanos, isNull);
      expect(info.denoisedGpuFrameDurationInNanos, isNull);
      expect(info.beginFrameInNanos, isNull);
      expect(info.endFrameInNanos, isNull);
      expect(info.backendBeginFrameInNanos, isNull);
      expect(info.backendEndFrameInNanos, isNull);
      expect(info.gpuFrameCompleteInNanos, isNull);
    });

    test('maps a zero GPU completion time to null', () {
      final info = FrameTimingInfo.fromNative(
        frameId: 1,
        gpuFrameDuration: 1,
        denoisedGpuFrameDuration: 1,
        beginFrame: 1,
        endFrame: 1,
        backendBeginFrame: 1,
        backendEndFrame: 1,
        gpuFrameComplete: 0,
      );

      expect(info.gpuFrameCompleteInNanos, isNull);
    });
  });
}
