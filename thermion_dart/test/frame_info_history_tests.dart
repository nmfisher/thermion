@TestOn('vm')
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("frame_info_history");
  await testHelper.setup();

  // Filament reports a frame's GPU time a few frames after it is submitted,
  // so render enough frames for the earliest ones to complete. Back-to-back
  // renders left the history empty on Metal, so frames are paced like a
  // 60 Hz display.
  const framesToRender = 30;
  const framePeriod = Duration(milliseconds: 16);

  test('rejects a count below one', () async {
    expect(() => FilamentApp.instance!.getFrameInfoHistory(count: 0), throwsRangeError);
  });

  test('returns recent frames, newest first', () async {
    await testHelper.withViewer((viewer) async {
      for (var i = 0; i < framesToRender; i++) {
        await FilamentApp.instance!.render();
        await Future<void>.delayed(framePeriod);
      }

      const requested = 5;
      final history = await FilamentApp.instance!.getFrameInfoHistory(count: requested);

      expect(history, isNotEmpty);
      expect(history.length, lessThanOrEqualTo(requested));
      for (var i = 1; i < history.length; i++) {
        expect(history[i].frameId, lessThan(history[i - 1].frameId));
      }
      for (final frame in history) {
        final begin = frame.beginFrameInNanos;
        final end = frame.endFrameInNanos;
        if (begin != null && end != null) {
          expect(end, greaterThanOrEqualTo(begin));
        }
        final gpu = frame.gpuFrameDurationInNanos;
        // A backend without timer queries reports zero.
        if (gpu != null) {
          expect(gpu, greaterThanOrEqualTo(0));
        }
      }

      // More than the renderer keeps returns what it has, not an error.
      final everything = await FilamentApp.instance!.getFrameInfoHistory(count: 1000);
      expect(everything.length, greaterThanOrEqualTo(history.length));
      expect(everything.first.frameId, history.first.frameId);
    });
  });
}
