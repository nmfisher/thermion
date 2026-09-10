import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final helper = TestHelper('capture_buffer_lifetime');
  await helper.setup();

  for (final (format, type) in [
    (TextureFormat.RGBA8, PixelDataType.UBYTE),
    (TextureFormat.RGBA8, PixelDataType.FLOAT),
    (TextureFormat.RGBA32F, PixelDataType.FLOAT),
  ]) {
    test('capture returns completed independent $format / $type pixels', () async {
      final (viewer, swapChain) = await helper.createViewer(
        bg: kRed,
        createRenderTarget: format == TextureFormat.RGBA32F,
      );
      // Use an attachment so browser presentation cannot clear the framebuffer
      // between queued calls. Match the attachment's supported readback type.
      final target = format == TextureFormat.RGBA8 ? await FilamentApp.instance!.createRenderTarget(512, 512) : null;
      final color = await target?.getColorTexture();
      final depth = await target?.getDepthTexture();
      if (target != null) await viewer.view.setRenderTarget(target);
      try {
        await helper.capture(
          viewer.view,
          null,
          swapChain: swapChain,
          pixelDataType: type,
        ); // Warm up backend shader compilation.
        final first = (await helper.capture(
          viewer.view,
          null,
          swapChain: swapChain,
          pixelDataType: type,
        ))[viewer.view]!;
        final viewport = await viewer.view.getViewport();
        expect(first.length, viewport.width * viewport.height * 4 * (type == PixelDataType.FLOAT ? 4 : 1));
        if (type == PixelDataType.UBYTE) {
          expect(first.take(4), [255, 0, 0, 255]);
        } else {
          final floats = Float32List.view(first.buffer, first.offsetInBytes, first.length ~/ 4);
          expect(floats[0], closeTo(1, 0.01));
          expect(floats[1], closeTo(0, 0.01));
          expect(floats[2], closeTo(0, 0.01));
          expect(floats[3], closeTo(1, 0.01));
        }
        // The returned result is managed storage; another capture cannot reuse it.
        first.fillRange(0, first.length, 0x5a);
        final second = (await helper.capture(
          viewer.view,
          null,
          swapChain: swapChain,
          pixelDataType: type,
        ))[viewer.view]!;
        expect(second, isNot(everyElement(0x5a)));
        expect(first, everyElement(0x5a));
      } finally {
        await viewer.dispose();
        if (target != null) await target.destroy();
        await color?.destroy();
        await depth?.destroy();
        await helper.disposeColorGradings();
        await FilamentApp.instance!.destroySwapChain(swapChain);
      }
    });
  }
}
