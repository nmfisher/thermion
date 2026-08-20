import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

/// Headless coverage for the Dart side of the Flutter-synchronized Linux
/// render loop. Native setters only retain the null test handles, and
/// [FrameScheduler.requestRender] replaces native render admission.
///
/// This remains one test because Flutter persistent frame callbacks cannot be
/// unregistered from the shared test binding.
void main() {
  testWidgets(
    'FrameScheduler owns Linux timing and pairs callbacks with admitted frames',
    (tester) async {
      final scheduler = FrameScheduler.instance;
      final realRequestRender = scheduler.requestRender;
      scheduler.reset();
      final scheduledAtStart = scheduler.scheduledFrameCount;

      addTearDown(() {
        scheduler.requestRender = realRequestRender;
        scheduler.reset();
      });

      var requests = 0;
      var admitFrames = true;
      scheduler.requestRender = (_) {
        requests++;
        return admitFrames;
      };

      var callbackCalls = 0;
      Completer<void>? callbackGate;
      scheduler.setOnFrame(() async {
        callbackCalls++;
        await callbackGate?.future;
      });

      Future<void> start() => scheduler.startFlutterSynced(
        renderThreadHandle: ffi.Pointer.fromAddress(0),
        renderManagerHandle: ffi.Pointer.fromAddress(0),
        postRenderCallback: ffi.Pointer.fromAddress(0),
        postRenderUserData: ffi.Pointer.fromAddress(0),
      );

      await start();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 2);
      expect(callbackCalls, 2);
      expect(scheduler.scheduledFrameCount, scheduledAtStart + 2);

      // Native throttle or render-thread rejections do not run the callback.
      admitFrames = false;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 4);
      expect(callbackCalls, 2);
      expect(scheduler.scheduledFrameCount, scheduledAtStart + 2);

      // A callback still in flight prevents another native render admission;
      // Linux renders and Dart callbacks therefore remain paired 1:1.
      admitFrames = true;
      callbackGate = Completer<void>();
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 5);
      expect(callbackCalls, 3);
      expect(scheduler.isRendering, isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 5);
      expect(callbackCalls, 3);

      callbackGate.complete();
      callbackGate = null;
      await tester.pump();
      expect(requests, 6);
      expect(callbackCalls, 4);

      // Pause stops requests and re-arming; resume explicitly re-arms Linux.
      scheduler.pause();
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 6);
      scheduler.resume();
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 7);
      expect(callbackCalls, 5);

      scheduler.stop();
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 7);

      // Persistent callbacks cannot be removed. Restarting must reuse the
      // existing registration instead of producing duplicate frame requests.
      await start();
      await tester.pump(const Duration(milliseconds: 16));
      expect(requests, 8);
      expect(callbackCalls, 6);
      expect(scheduler.scheduledFrameCount, scheduledAtStart + 6);
    },
  );
}
