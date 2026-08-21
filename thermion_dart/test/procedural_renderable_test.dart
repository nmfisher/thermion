import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

/// Tests for attribute-less (procedural) rendering: a renderable whose
/// geometry is generated entirely in the vertex shader from getVertexIndex(),
/// with no IndexBuffer and a VertexBuffer built with bufferCount(0).
///
/// The material (examples/assets/proceduralquad.mat, ported from Filament's
/// samples/materials/proceduralTextureQuad.mat) draws a 1x1 quad in the world
/// XY plane with a red/green gradient keyed to the procedural UV, so pixel
/// values can be asserted without a texture.
void main() async {
  final testHelper = TestHelper("procedural_renderable");
  await testHelper.setup();

  const viewportSize = 512;
  const tolerance = 0.08;

  Future<MaterialInstance> loadProceduralQuadMaterial() async {
    final material = await FilamentApp.instance!.createMaterial(
      await loadResourceBytes("${testHelper.assetsDir}/proceduralquad.filamat"),
    );
    return material.createInstance();
  }

  /// Builds an attribute-less vertex buffer: bufferCount(0), no declared
  /// attributes, no setBufferAt() uploads.
  Future<VertexBuffer> createAttributelessVertexBuffer(int vertexCount) async {
    return (FilamentApp.instance!.renderableManager.createVertexBufferBuilder()
          ..bufferCount(0)
          ..vertexCount(vertexCount))
        .build();
  }

  /// Reinterprets a float capture as RGBA floats.
  Float32List asFloats(Uint8List bytes) =>
      bytes.buffer.asFloat32List(bytes.offsetInBytes, viewportSize * viewportSize * 4);

  /// Returns whether a pixel shows the procedural quad (blue channel ~0)
  /// versus the blue background (blue channel ~1).
  bool isQuadPixel(Float32List pixels, int x, int y) {
    final i = (y * viewportSize + x) * 4;
    return pixels[i + 2] < 0.5;
  }

  /// Bounding box (x0, y0, x1, y1) of the quad pixels in a capture.
  (int, int, int, int) quadBounds(Float32List pixels) {
    var x0 = viewportSize;
    var y0 = viewportSize;
    var x1 = 0;
    var y1 = 0;
    for (var y = 0; y < viewportSize; y++) {
      for (var x = 0; x < viewportSize; x++) {
        if (isQuadPixel(pixels, x, y)) {
          if (x < x0) x0 = x;
          if (y < y0) y0 = y;
          if (x > x1) x1 = x;
          if (y > y1) y1 = y;
        }
      }
    }
    return (x0, y0, x1, y1);
  }

  test('attribute-less quad renders from getVertexIndex()', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kBlue)
        .setCameraLookAt(Vector3(0, 0, 2), focus: Vector3.zero())
        .execute((result) async {
      final app = FilamentApp.instance!;
      final renderableManager = app.renderableManager;

      final vertexBuffer = await createAttributelessVertexBuffer(6);
      expect(vertexBuffer.getVertexCount(), equals(6));

      final material = await loadProceduralQuadMaterial();

      final entity = await app.createEntity();
      final renderableBuilder = renderableManager.createBuilder(1)
        ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
        ..geometryNonIndexed(0, PrimitiveType.TRIANGLES, vertexBuffer, 0, 6)
        ..material(0, material);

      final success = await renderableBuilder.build(entity);
      expect(success, true);
      expect(renderableManager.isRenderable(entity), true);

      final scene = await result.viewer.view.getScene();
      await scene.addEntity(entity);

      final pixels = asFloats((await testHelper.capture(result.viewer.view, "procedural_quad"))[result.viewer.view]!);

      // The quad must cover a substantial region of the frame.
      final (x0, y0, x1, y1) = quadBounds(pixels);
      expect(x1 - x0, greaterThan(viewportSize * 0.4));
      expect(y1 - y0, greaterThan(viewportSize * 0.4));

      // Image corners stay background blue; the center shows the gradient.
      expect(isQuadPixel(pixels, 10, 10), false);
      expect(isQuadPixel(pixels, viewportSize - 11, viewportSize - 11), false);
      expect(isQuadPixel(pixels, viewportSize ~/ 2, viewportSize ~/ 2), true);

      // Center of the quad is the middle of the red/green gradient.
      final centerIndex = ((viewportSize ~/ 2) * viewportSize + (viewportSize ~/ 2)) * 4;
      expect(pixels[centerIndex], closeTo(0.5, tolerance));
      expect(pixels[centerIndex + 1], closeTo(0.5, tolerance));
      expect(pixels[centerIndex + 2], closeTo(0.0, tolerance));

      // The red channel increases along the procedural UV's x axis.
      final leftIndex = centerIndex - 80 * 4;
      final rightIndex = centerIndex + 80 * 4;
      expect(pixels[rightIndex] - pixels[leftIndex], greaterThan(0.1));

      await vertexBuffer.destroy();
    });
  });

  test('setGeometryAtNonIndexed changes the vertex range at runtime', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kBlue)
        .setCameraLookAt(Vector3(0, 0, 2), focus: Vector3.zero())
        .execute((result) async {
      final app = FilamentApp.instance!;
      final renderableManager = app.renderableManager;

      final vertexBuffer = await createAttributelessVertexBuffer(6);
      final material = await loadProceduralQuadMaterial();

      final entity = await app.createEntity();
      final renderableBuilder = renderableManager.createBuilder(1)
        ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
        ..geometryNonIndexed(0, PrimitiveType.TRIANGLES, vertexBuffer, 0, 3)
        ..material(0, material);

      final success = await renderableBuilder.build(entity);
      expect(success, true);

      final scene = await result.viewer.view.getScene();
      await scene.addEntity(entity);

      // Only the first triangle is drawn: one diagonal half of the quad.
      final halfPixels =
          asFloats((await testHelper.capture(result.viewer.view, "procedural_triangle"))[result.viewer.view]!);
      final (hx0, hy0, hx1, hy1) = quadBounds(halfPixels);
      expect(hx1 - hx0, greaterThan(viewportSize * 0.2));

      // The triangle covers the half-plane left of its diagonal, so the
      // horizontal middle of the left edge is quad and of the right edge is
      // background (independent of any vertical flip in the readback).
      final midY = (hy0 + hy1) ~/ 2;
      final leftX = hx0 + (hx1 - hx0) ~/ 5;
      final rightX = hx1 - (hx1 - hx0) ~/ 5;
      expect(isQuadPixel(halfPixels, leftX, midY), true);
      expect(isQuadPixel(halfPixels, rightX, midY), false);

      // Swap in the full vertex range at runtime.
      final swapped = await renderableManager.setGeometryAtNonIndexed(
        entity,
        0,
        PrimitiveType.TRIANGLES,
        vertexBuffer,
        0,
        6,
      );
      expect(swapped, true);

      final fullPixels =
          asFloats((await testHelper.capture(result.viewer.view, "procedural_triangle_to_quad"))[result.viewer.view]!);
      expect(isQuadPixel(fullPixels, leftX, midY), true);
      expect(isQuadPixel(fullPixels, rightX, midY), true);

      await vertexBuffer.destroy();
    });
  });
}
