// Native-side guard for the web-only entrypoint
// (package:thermion_dart/thermion_dart_web.dart): on native platforms the
// extension getters must report unavailable (null) and offscreen
// (present-skip) swapchains must throw UnsupportedError — without touching
// any web-only engine entry point.
//
// Drive with:
//   xvfb-run -a dart test test/webgpu_device_export_native_test.dart
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart_web.dart';

import 'src/test_io.dart';

void main() {
  group('thermion_dart_web on native', () {
    late FFIFilamentApp app;

    setUpAll(() async {
      await FFIFilamentApp.create(
        config: FFIFilamentConfig(backend: defaultTestBackend, loadResource: loadResourceBytes),
      );
      app = FilamentApp.instance! as FFIFilamentApp;
    });
    tearDownAll(() => app.destroy());

    test('webGPUDevice is null on native backends', () {
      expect(app.webGPUDevice, isNull);
    });

    test('offscreenCanvasSelector is null on native backends', () {
      expect(app.offscreenCanvasSelector, isNull);
    });

    test('createOffscreenSwapChain throws UnsupportedError on native', () async {
      // The guard throws synchronously, before any future is created.
      expect(() => app.createOffscreenSwapChain(), throwsUnsupportedError);
      // The rejected call must not have registered a swapchain.
      expect(await app.getSwapChains(), isEmpty);
    });

    test('a normal swapchain still works', () async {
      final swapChain = await app.createHeadlessSwapChain(8, 8);
      expect(await app.getSwapChains(), contains(swapChain));
      await app.destroySwapChain(swapChain);
      expect(await app.getSwapChains(), isEmpty);
    });
  });
}
