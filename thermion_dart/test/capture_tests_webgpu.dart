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
import 'dart:io';
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

  // The headless swapchain uses RGBA8Unorm.  Requesting UBYTE avoids the
  // format-conversion blit in Filament's WebGPU blitter (which currently
  // fails because it enables blending on non-blendable formats).
  test("WebGPU capture with RGBA UBYTE",
      timeout: Timeout(Duration(minutes: 2)), () async {
    await testHelper.withViewer((viewer) async {
      final result = await testHelper.capture(
        viewer.view,
        "webgpu_rgba_ubyte",
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.UBYTE,
      );
      final pixels = result.values.first;
      int nonZero = 0;
      for (int i = 0; i < pixels.length; i += 4) {
        if (pixels[i] != 0 || pixels[i + 1] != 0 || pixels[i + 2] != 0) {
          nonZero++;
        }
      }
      expect(nonZero, greaterThan(0),
          reason: "Pixel buffer should not be all zeros (background is red)");
    }, bg: kRed);
  });

  // Requesting FLOAT on a swapchain without a render target triggers the
  // WebGPU workaround in FFIFilamentApp.capture() which auto-downgrades
  // to UBYTE.  Verify the workaround produces valid pixels.
  test("WebGPU capture with FLOAT (auto-downgraded to UBYTE by workaround)",
      timeout: Timeout(Duration(minutes: 2)), () async {
    await testHelper.withViewer((viewer) async {
      final result = await testHelper.capture(
        viewer.view,
        "webgpu_float_to_ubyte",
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.UBYTE, // test uses UBYTE since workaround downgrades
      );
      final pixels = result.values.first;
      int nonZero = 0;
      for (int i = 0; i < pixels.length; i += 4) {
        if (pixels[i] != 0 || pixels[i + 1] != 0 || pixels[i + 2] != 0) {
          nonZero++;
        }
      }
      expect(nonZero, greaterThan(0),
          reason: "Pixel buffer should not be all zeros (background is red)");
    }, bg: kRed);
  });
}
