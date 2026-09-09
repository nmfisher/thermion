import 'dart:async';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("render_thread");

  await testHelper.setup();

  test("capture with RGBA byte", () async {
    await testHelper.withViewer((viewer) async {
      await testHelper.capture(
        viewer.view,
        "capture_rgba_float",
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.FLOAT,
      );
      await testHelper.capture(
        viewer.view,
        "capture_rgba_byte",
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.UBYTE,
      );
    }, bg: kRed);
  });
  test("capture excludes normal frames until async preparation finishes", () async {
    await testHelper.withViewer((viewer) async {
      final app = FilamentApp.instance!;
      final surface = app.renderManager.getAttachedSwapChains(viewer.view).single;
      final entered = Completer<void>();
      final release = Completer<void>();
      final captured = app.capture(
        surface,
        view: viewer.view,
        beforeRender: (_) async {
          entered.complete();
          await release.future;
        },
      );
      await entered.future;
      var rendered = false;
      final rendering = app.render().then((_) => rendered = true);
      try {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(rendered, isFalse, reason: 'A capture frame is still open');
      } finally {
        release.complete();
        await captured;
        await rendering;
      }
      expect(rendered, isTrue);
    }, bg: kRed);
  });

  test("failed capture closes its frame and releases queued rendering", () async {
    await testHelper.withViewer((viewer) async {
      final app = FilamentApp.instance!;
      final surface = app.renderManager.getAttachedSwapChains(viewer.view).single;
      await expectLater(
        app.capture(
          surface,
          view: viewer.view,
          beforeRender: (_) async {
            await Future<void>.delayed(Duration.zero);
            throw StateError('capture preparation failed');
          },
        ),
        throwsStateError,
      );
      await app.render();
      final result = await app.capture(surface, view: viewer.view);
      expect(result.single.$2, isNotEmpty);
    }, bg: kRed);
  });
}
