// Headless capture tests using the WebGPU backend (Dawn) on Linux.
// Exercises the full beginFrame → render → readPixels → endFrame pipeline
// and writes the captured buffers as PNGs to test/output/capture_webgpu/.
//
// Requires:
//   - hooks.user_defines.thermion_dart.webgpu: true in pubspec.yaml
//   - A Vulkan ICD on the system (lavapipe is fine for headless CPU runs)
//   - Filament built from main (post-v1.71.5) which implements readPixels
//     for the WebGPU backend
//
// Drive with:
//   dart test test/capture_tests_webgpu.dart
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  setUpAll(() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((r) => print(r));
  });

  final testHelper = TestHelper("capture_webgpu", backend: Backend.WEBGPU);
  await testHelper.setup();

  // Runs [fn] with the viewer AND its swapchain (unlike withViewer, which
  // only exposes the viewer). The capture tests must pass the swapchain to
  // capture() explicitly: FFIFilamentApp.capture refuses to pick one when
  // multiple swapchains are registered, and a failed/timed-out test can leak
  // its swapchain and leave more than one registered for the next test.
  Future<void> withViewerAndSwapChain(
    Future Function(ThermionViewer viewer, SwapChain swapChain) fn, {
    img.Color? bg,
  }) async {
    final (viewer, swapChain) = await testHelper.createViewer(bg: bg);
    try {
      await fn(viewer, swapChain);
    } finally {
      await viewer.dispose();
      await testHelper.disposeColorGradings();
      await FilamentApp.instance!.destroySwapChain(swapChain);
    }
  }

  // The headless swapchain uses RGBA8Unorm.  Requesting UBYTE avoids the
  // format-conversion blit in Filament's WebGPU blitter (which currently
  // fails because it enables blending on non-blendable formats).
  test("WebGPU capture with RGBA UBYTE", timeout: Timeout(Duration(minutes: 2)), () async {
    await withViewerAndSwapChain((viewer, swapChain) async {
      final result = await testHelper.capture(
        viewer.view,
        "webgpu_rgba_ubyte",
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.UBYTE,
        swapChain: swapChain,
      );
      final pixels = result.values.first;
      int nonZero = 0;
      for (int i = 0; i < pixels.length; i += 4) {
        if (pixels[i] != 0 || pixels[i + 1] != 0 || pixels[i + 2] != 0) {
          nonZero++;
        }
      }
      expect(nonZero, greaterThan(0), reason: "Pixel buffer should not be all zeros (background is red)");
    }, bg: kRed);
  });

  // Requesting FLOAT on a swapchain without a render target triggers the
  // WebGPU workaround in FFIFilamentApp.capture() which silently downgrades
  // the read to UBYTE. Pass FLOAT here so the workaround path itself is
  // exercised (the first test above covers the explicit-UBYTE path).
  test(
    "WebGPU capture with FLOAT (auto-downgraded to UBYTE by workaround)",
    timeout: Timeout(Duration(minutes: 2)),
    () async {
      await withViewerAndSwapChain((viewer, swapChain) async {
        final result = await testHelper.capture(
          viewer.view,
          "webgpu_float_to_ubyte",
          pixelDataFormat: PixelDataFormat.RGBA,
          pixelDataType: PixelDataType.FLOAT, // capture() downgrades to UBYTE
          swapChain: swapChain,
        );
        final pixels = result.values.first;
        final viewport = await viewer.view.getViewport();
        // The workaround must have downgraded the read to UBYTE: one byte per
        // channel, not the 4 bytes a FLOAT buffer would occupy. If the read
        // had honored FLOAT, this buffer would be 4x larger.
        expect(
          pixels.length,
          viewport.width * viewport.height * 4,
          reason:
              "capture(FLOAT) on WebGPU must return a UBYTE-sized buffer "
              "(the workaround downgrade)",
        );
        int nonZero = 0;
        for (int i = 0; i < pixels.length; i += 4) {
          if (pixels[i] != 0 || pixels[i + 1] != 0 || pixels[i + 2] != 0) {
            nonZero++;
          }
        }
        expect(nonZero, greaterThan(0), reason: "Downgraded pixel buffer should not be all zeros (background is red)");
      }, bg: kRed);
    },
  );
}
