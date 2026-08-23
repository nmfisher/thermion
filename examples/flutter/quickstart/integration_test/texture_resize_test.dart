// Regression test for duplicate destruction of a texture descriptor during a
// widget resize.
//
// Run on a real target:
//
//   flutter test integration_test/texture_resize_test.dart -d macos
//   flutter test integration_test/texture_resize_test.dart -d linux
//   flutter test integration_test/texture_resize_test.dart -d <device-id>
//
// Windows updates its descriptor in place while other platforms replace it;
// teardown must serialize correctly with either resize strategy.
import 'dart:async';

import 'package:flutter/material.dart' hide View;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;
// ignore: implementation_imports
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resize and teardown destroy each texture exactly once',
    (tester) async {
      final viewer = await ThermionFlutterPlugin.createViewer();
      final size = ValueNotifier<Size>(const Size(160, 120));
      var textureUpdateCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ValueListenableBuilder<Size>(
              valueListenable: size,
              builder: (context, value, child) {
                return SizedBox(
                  width: value.width,
                  height: value.height,
                  child: ThermionWidgetInternal(
                    key: const ValueKey('resizable-thermion-surface'),
                    view: viewer.view,
                    surfaceWidgetBuilder: (descriptor, view) {
                      if (descriptor == null) {
                        return const SizedBox.expand();
                      }
                      return Texture(
                        textureId: descriptor.flutterTextureId,
                      );
                    },
                    onTextureUpdated: (descriptor) {
                      if (descriptor != null) {
                        textureUpdateCount++;
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => textureUpdateCount == 1,
        'the initial texture allocation',
      );

      size.value = const Size(240, 180);
      await tester.pump();
      await _pumpUntil(
        tester,
        () => textureUpdateCount == 2,
        'the resized texture allocation',
      );

      // Let errors from unawaited descriptor cleanup reach the test binding.
      // Before the fix, Darwin throws here because resizeTexture() has already
      // destroyed the descriptor and ThermionWidgetInternal destroys it again.
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Hold one scheduler frame open so resizeTexture() deterministically
      // remains in flight until teardown has been queued behind it.
      final scheduler = FrameScheduler.instance;
      final renderGate = Completer<void>();
      scheduler.pause();
      await _pumpUntil(
        tester,
        () => !scheduler.isRendering,
        'the current frame to finish',
      );
      scheduler.setFrameHandler(() async {
        await renderGate.future;
        await FilamentApp.instance?.render();
      });
      scheduler.resume();
      await _pumpUntil(
        tester,
        () => scheduler.isRendering,
        'the controlled frame to start',
      );

      // Start another resize, then unmount while the native operation is in
      // flight. Teardown must wait for it, release the final platform binding,
      // and destroy only the final descriptor.
      size.value = const Size(320, 240);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 101));
      await _pumpUntil(
        tester,
        () => scheduler.isPaused,
        'resizeTexture to pause behind the controlled frame',
      );
      final updatesAtUnmount = textureUpdateCount;
      expect(
        updatesAtUnmount,
        2,
        reason: 'the native resize must still be in flight at unmount',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      renderGate.complete();
      await _pumpUntil(
        tester,
        () => !scheduler.isPaused,
        'the in-flight resize to complete',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        textureUpdateCount,
        updatesAtUnmount,
        reason: 'an allocation completing after dispose must not notify',
      );
      expect(tester.takeException(), isNull);

      scheduler.stop();
      await viewer.dispose();
      size.dispose();
    },
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  String operation,
) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 15)) {
      throw TestFailure('Timed out waiting for $operation');
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
}
