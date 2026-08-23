import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

/// Headless coverage for the Dart side of the Flutter-synchronized Linux
/// frame source.
///
/// This remains one test because Flutter persistent frame callbacks cannot be
/// unregistered from the shared test binding.
void main() {
  testWidgets(
    'FrameScheduler owns Linux timing and pairs callbacks with admitted frames',
    (tester) async {
      final scheduler = FrameScheduler.instance;
      scheduler.reset();
      final scheduledAtStart = scheduler.scheduledFrameCount;

      addTearDown(scheduler.reset);

      var callbackCalls = 0;
      var targetFps = 0;
      Completer<void>? callbackGate;
      scheduler.setOnFrame(() async {
        callbackCalls++;
        await callbackGate?.future;
      });

      Future<void> start() =>
          scheduler.startFlutterSynced(targetFps: () => targetFps);

      await start();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(callbackCalls, 2);
      expect(scheduler.scheduledFrameCount, scheduledAtStart + 2);

      // A callback still in flight prevents another frame from being
      // admitted, matching the normal native callback path.
      callbackGate = Completer<void>();
      await tester.pump(const Duration(milliseconds: 16));
      expect(callbackCalls, 3);
      expect(scheduler.isRendering, isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(callbackCalls, 3);

      callbackGate.complete();
      callbackGate = null;
      await tester.pump();
      expect(callbackCalls, 4);

      // Linux applies the shared target framerate before entering the common
      // callback pipeline.
      scheduler.stop();
      targetFps = 30;
      await start();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 10));
      expect(callbackCalls, 5);
      await tester.pump(const Duration(milliseconds: 24));
      expect(callbackCalls, 6);

      // Pause stops requests and re-arming; resume explicitly re-arms Linux.
      scheduler.pause();
      await tester.pump(const Duration(milliseconds: 16));
      expect(callbackCalls, 6);
      scheduler.resume();
      await tester.pump(const Duration(milliseconds: 34));
      expect(callbackCalls, 7);

      scheduler.stop();
      await tester.pump(const Duration(milliseconds: 16));
      expect(callbackCalls, 7);

      // Persistent callbacks cannot be removed. Restarting must reuse the
      // existing registration instead of producing duplicate frame requests.
      await start();
      await tester.pump(const Duration(milliseconds: 16));
      expect(callbackCalls, 8);
      expect(scheduler.scheduledFrameCount, scheduledAtStart + 8);
    },
  );
}
