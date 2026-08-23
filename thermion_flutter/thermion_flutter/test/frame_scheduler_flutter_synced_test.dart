import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

/// Headless coverage for the Dart side of the Flutter-synchronized Linux
/// frame source.
///
/// This remains one test because Flutter persistent frame callbacks cannot be
/// unregistered from the shared test binding.
void main() {
  testWidgets('FrameScheduler dispatches handlers for accepted Linux ticks', (
    tester,
  ) async {
    final scheduler = FrameScheduler.instance;
    scheduler.reset();
    final dispatchedAtStart = scheduler.dispatchedFrameCount;

    addTearDown(scheduler.reset);

    var handlerCalls = 0;
    var targetFps = 0;
    Completer<void>? handlerGate;
    scheduler.setFrameHandler(() async {
      handlerCalls++;
      await handlerGate?.future;
    });

    Future<void> start() =>
        scheduler.startFlutterSynced(targetFps: () => targetFps);

    await start();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(handlerCalls, 2);
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
  });
}
