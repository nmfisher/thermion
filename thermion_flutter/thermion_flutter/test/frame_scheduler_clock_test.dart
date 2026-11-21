import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

// Widget tests advance a fake engine clock. Keep both sampled clocks in step
// with it while independently controlling callback delay and clock offsets.
class _FrameClock {
  int delayUs = 0;
  int steadyOffsetUs = 1000000;
  int? steadyNowOverrideUs;
  final frames = <int>[];
  late final scheduler = FrameScheduler.forTesting(
    sourceClockUs: () => frameUs + delayUs,
    steadyClockUs: () =>
        steadyNowOverrideUs ?? frameUs + delayUs + steadyOffsetUs,
  );

  int get frameUs =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
  int get expectedFrameNanos => (frameUs + steadyOffsetUs) * 1000;

  Future<void> start({int fps = 0}) async {
    // Persistent callbacks cannot be removed. Reset deactivates this instance
    // so it cannot dispatch or schedule frames in subsequent tests.
    addTearDown(scheduler.reset);
    scheduler.setFrameHandler((timestamp) async => frames.add(timestamp));
    await scheduler.startFlutterSynced(targetFps: () => fps);
  }
}

void main() {
  testWidgets('time dilation changes neither frame time nor FPS pacing', (
    tester,
  ) async {
    final clock = _FrameClock();
    timeDilation = 2;
    try {
      await clock.start(fps: 30);
      await tester.pump(const Duration(milliseconds: 16));
      expect(clock.frames.single, clock.expectedFrameNanos);
      await tester.pump(const Duration(milliseconds: 16));
      expect(clock.frames, hasLength(1));
      await tester.pump(const Duration(milliseconds: 18));
      expect(clock.frames, hasLength(2));
      expect(clock.frames.last - clock.frames.first, 34000000);
      expect(clock.frames.last, clock.expectedFrameNanos);
    } finally {
      // The binding checks this before addTearDown callbacks run.
      timeDilation = 1;
    }
  });

  testWidgets('epoch reset preserves elapsed time and the next FPS deadline', (
    tester,
  ) async {
    final clock = _FrameClock();
    await clock.start(fps: 30);
    await tester.pump(const Duration(milliseconds: 16));
    SchedulerBinding.instance.resetEpoch();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clock.frames, hasLength(2));
    expect(clock.frames.last - clock.frames.first, 100000000);
    expect(clock.frames.last, clock.expectedFrameNanos);
  });

  testWidgets('subtracts callback delay including on the first frame', (
    tester,
  ) async {
    final clock = _FrameClock()..delayUs = 12000;
    await clock.start();
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.frames.single, clock.expectedFrameNanos);
    clock.delayUs = 4000;
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.frames.last, clock.expectedFrameNanos);
    expect(clock.frames.last - clock.frames.first, 16000000);
  });

  testWidgets('resamples the clock offset after pause and resume', (
    tester,
  ) async {
    final clock = _FrameClock();
    await clock.start();
    await tester.pump(const Duration(milliseconds: 16));
    clock.scheduler.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(clock.frames, hasLength(1));
    clock.steadyOffsetUs += 500000;
    clock.delayUs = 3000;
    clock.scheduler.resume();
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.frames.last, clock.expectedFrameNanos);
  });

  testWidgets('clock corrections cannot move animation time backwards', (
    tester,
  ) async {
    final clock = _FrameClock();
    await clock.start();
    await tester.pump(const Duration(milliseconds: 16));
    clock.steadyOffsetUs -= 10000;
    await tester.pump(const Duration(milliseconds: 5));
    expect(clock.frames.last, clock.frames.first);
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.frames.last, clock.expectedFrameNanos);
    expect(clock.frames.last, greaterThan(clock.frames.first));
  });

  testWidgets('future frame timestamp falls back to current native time', (
    tester,
  ) async {
    final clock = _FrameClock()..delayUs = -1000;
    await clock.start();
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.frames.single, clock.expectedFrameNanos - 1000000);
  });

  testWidgets('an age larger than native uptime cannot underflow', (
    tester,
  ) async {
    final clock = _FrameClock()
      ..delayUs = 2000
      ..steadyNowOverrideUs = 1000;
    await clock.start();
    await tester.pump(const Duration(milliseconds: 16));
    expect(clock.frames.single, 1000000);
  });
}
