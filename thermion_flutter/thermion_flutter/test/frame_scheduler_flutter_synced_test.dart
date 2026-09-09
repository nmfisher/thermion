import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

/// Headless coverage for the Dart side of the Flutter-synchronized Linux
/// frame source.
///
void main() {
  testWidgets('FrameScheduler dispatches handlers for accepted Linux ticks', (
    tester,
  ) async {
    int frameUs() =>
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    final scheduler = FrameScheduler.forTesting(
      sourceClockUs: frameUs,
      steadyClockUs: () => frameUs() + 1000000,
    );
    final dispatchedAtStart = scheduler.dispatchedFrameCount;

    addTearDown(scheduler.reset);

    var handlerCalls = 0;
    final timestamps = <int>[];
    var targetFps = 0;
    Completer<void>? handlerGate;
    scheduler.setFrameHandler((timestamp) async {
      timestamps.add(timestamp);
      handlerCalls++;
      await handlerGate?.future;
    });

    Future<void> start() =>
        scheduler.startFlutterSynced(targetFps: () => targetFps);

    await start();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 2);
    expect(timestamps[1] - timestamps[0], 16000000);
    expect(timestamps[0], greaterThan(0));
    expect(scheduler.dispatchedFrameCount, dispatchedAtStart + 2);

    // A handler still in flight prevents another tick from dispatching
    // work, matching the normal native tick path.
    handlerGate = Completer<void>();
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 3);
    expect(scheduler.isRendering, isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 3);

    handlerGate.complete();
    handlerGate = null;
    await tester.pump();
    expect(handlerCalls, 4);

    // Linux applies the shared target framerate before entering the common
    // handler pipeline.
    scheduler.stop();
    targetFps = 30;
    await start();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 10));
    expect(handlerCalls, 5);
    await tester.pump(const Duration(milliseconds: 24));
    expect(handlerCalls, 6);

    // Pause stops requests and re-arming; resume explicitly re-arms Linux.
    scheduler.pause();
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 6);
    scheduler.resume();
    await tester.pump(const Duration(milliseconds: 34));
    expect(handlerCalls, 7);

    scheduler.stop();
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 7);

    // Persistent callbacks cannot be removed. Restarting must reuse the
    // existing registration instead of producing duplicate frame requests.
    await start();
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 8);
    expect(scheduler.dispatchedFrameCount, dispatchedAtStart + 8);

    // A synchronous throw must release the guard just like a failed Future.
    scheduler.reset();
    var failures = 0;
    scheduler.setFrameHandler((_) {
      failures++;
      throw StateError('synchronous frame failure');
    });
    await start();
    await tester.pump(const Duration(milliseconds: 34));
    expect(scheduler.isRendering, isFalse);
    await tester.pump(const Duration(milliseconds: 34));
    expect(failures, 2);
    scheduler.setFrameHandler(
      (_) => Future<void>.error(StateError('async failure')),
    );
    await tester.pump(const Duration(milliseconds: 34));
    expect(scheduler.isRendering, isFalse);

    // Reset can dispatch a new handler while a previous handler is finishing.
    // Its completion must not clear the current generation's in-flight guard.
    scheduler.reset();
    targetFps = 0;
    final oldFrame = Completer<void>();
    scheduler.setFrameHandler((_) => oldFrame.future);
    await start();
    await tester.pump(const Duration(milliseconds: 16));
    expect(scheduler.isRendering, isTrue);
    scheduler.reset();
    final newFrame = Completer<void>();
    var newCalls = 0;
    scheduler.setFrameHandler((_) {
      newCalls++;
      return newFrame.future;
    });
    await start();
    await tester.pump(const Duration(milliseconds: 16));
    oldFrame.complete();
    await tester.idle();
    expect(scheduler.isRendering, isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(newCalls, 1);
    newFrame.complete();
    await tester.idle();
    expect(scheduler.isRendering, isFalse);
  });
}
