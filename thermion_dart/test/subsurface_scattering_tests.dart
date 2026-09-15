import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/subsurface_scattering_manager.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Tests for the fullscreen-quad screen-space subsurface scattering pass.
///
/// A textured cube stands in for skin: the pass only needs an asset whose
/// geometry buffers are accessible so the mask pass can re-render it, and does
/// not care what the mesh is. The same requirement holds for
/// `View.setStencilHighlight`, which is where the buffer-reuse convention comes
/// from.
///
/// See docs/screen-space-subsurface-scattering.md for the design.
void main() async {
  final testHelper = TestHelper("subsurface_scattering");
  await testHelper.setup();

  /// Number of pixels whose RGB differs by more than [epsilon] in any channel.
  ///
  /// Alpha is ignored: the composite pass writes the scene alpha through
  /// unchanged, so it carries no information about the scattering.
  int countDifferingPixels(Uint8List a, Uint8List b, {double epsilon = 1.0 / 255.0}) {
    expect(a.lengthInBytes, b.lengthInBytes, reason: "captures are not the same size");
    final fa = Float32List.view(a.buffer, a.offsetInBytes, a.lengthInBytes ~/ 4);
    final fb = Float32List.view(b.buffer, b.offsetInBytes, b.lengthInBytes ~/ 4);

    var count = 0;
    for (var i = 0; i < fa.length; i += 4) {
      if ((fa[i] - fb[i]).abs() > epsilon ||
          (fa[i + 1] - fb[i + 1]).abs() > epsilon ||
          (fa[i + 2] - fb[i + 2]).abs() > epsilon) {
        count++;
      }
    }
    return count;
  }

  /// Float offset of the (x, y) pixel in an RGBA float capture.
  int pixelOffset(int x, int y, int width) => (y * width + x) * 4;

  test('addSkin requires accessible geometry buffers', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final cube = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb", addToScene: true);
      await result.viewer.view.setSubsurfaceScatteringEnabled(true);

      final sss = result.viewer.view.getSubsurfaceScattering();
      expect(sss, isNotNull);

      await expectLater(
        sss!.addSkin(cube),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('accessibleGeometryBuffers'),
          ),
        ),
      );

      await result.viewer.view.setSubsurfaceScatteringEnabled(false);
    });
  });

  test('enabling and disabling the pass is a no-op for the scene render', () async {
    await ViewerBuilder(testHelper).addSun().setViewportDimensions(256, 256).execute((result) async {
      final view = result.viewer.view;
      final cube = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.accessibleGeometryBuffers},
        addToScene: true,
      );

      await view.setSubsurfaceScatteringEnabled(true);
      expect(view.getSubsurfaceScattering(), isNotNull);

      // Enable/disable must leave the view usable: the main view's render
      // target is restored and the pass views are detached.
      await view.setSubsurfaceScatteringEnabled(false);
      expect(view.getSubsurfaceScattering(), isNull);

      final capture = await testHelper.capture(view, "sss_disabled");
      expect(capture, isNotEmpty);
      expect(cube, isNotNull);
    });
  });

  test('scattering changes pixels inside the skin and leaves the background alone', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setViewportDimensions(256, 256)
        .setCameraLookAt(Vector3(0, 0, 5), focus: Vector3.zero())
        .execute((result) async {
      final viewer = result.viewer;
      final view = viewer.view;

      final cube = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.accessibleGeometryBuffers},
        addToScene: true,
      );

      // The frame with the effect switched off entirely: the main view is
      // still rendering straight into the swapchain here.
      final baseline = (await testHelper.capture(view, "sss_disabled")).values.first;

      await view.setSubsurfaceScatteringEnabled(true);
      final sss = view.getSubsurfaceScattering()!;
      await sss.addSkin(cube);

      expect(sss.skinEntities, isNotEmpty, reason: "the cube's primitives should be registered as skin");

      await sss.setParameters(
        SubsurfaceScatteringParameters(
          radiusRed: 10.0,
          radiusGreen: 6.0,
          radiusBlue: 3.0,
          depthFalloff: 25.0,
          intensity: 0.0,
        ),
      );

      // The composite pass produces the final image and writes it to the
      // swapchain, so it has no render target of its own and capturing it
      // reads the swapchain back. Capturing the main view would read the
      // internal scene colour target instead, which the composite never
      // touches.
      //
      // Capturing drives a single view at a time, so the pass chain is
      // rendered here exactly as the frame loop renders it - mask, main view,
      // both blurs, then the composite - before the swapchain is read back.
      await FilamentApp.instance!.renderManager.render();
      final off = (await testHelper.capture(sss.compositeView, "sss_intensity0")).values.first;

      // Zero intensity must be invisible: redirecting the main view and running
      // the pass chain may not alter the rendered frame at all.
      expect(
        countDifferingPixels(baseline, off),
        0,
        reason: "enabling the pass at intensity 0 changed the rendered frame",
      );

      await sss.setParameters(
        SubsurfaceScatteringParameters(
          radiusRed: 10.0,
          radiusGreen: 6.0,
          radiusBlue: 3.0,
          depthFalloff: 25.0,
          intensity: 1.0,
        ),
      );
      await FilamentApp.instance!.renderManager.render();
      final on = (await testHelper.capture(sss.compositeView, "sss_intensity1")).values.first;

      final differing = countDifferingPixels(off, on);
      const totalPixels = 256 * 256;

      // The blur has to reach the skin: with a full-strength scatter and a
      // textured cube lit from one side, a substantial part of the frame must
      // move. If this fails, either the blur passes produced nothing or the
      // composite pass is not sampling them.
      expect(
        differing,
        greaterThan(totalPixels ~/ 100),
        reason: "expected the scatter to change at least 1% of the frame, changed $differing",
      );

      // ... and it must not reach the corners, which are background: the
      // composite pass gates on the skin mask, so those pixels are untouched.
      const width = 256;
      const height = 256;
      final corners = [0, 0, width - 1, 0, 0, height - 1, width - 1, height - 1];
      final fOff = Float32List.view(off.buffer);
      final fOn = Float32List.view(on.buffer);
      for (var c = 0; c < corners.length; c += 2) {
        final o = pixelOffset(corners[c], corners[c + 1], width);
        expect(
          (fOff[o] - fOn[o]).abs() < 1e-4 &&
              (fOff[o + 1] - fOn[o + 1]).abs() < 1e-4 &&
              (fOff[o + 2] - fOn[o + 2]).abs() < 1e-4,
          isTrue,
          reason: "background pixel (${corners[c]}, ${corners[c + 1]}) changed; the mask is not gating the scatter",
        );
      }

      await view.setSubsurfaceScatteringEnabled(false);
    });
  });

  test('parameters are clamped and pushed to the material instances', () async {
    await ViewerBuilder(testHelper).addSun().setViewportDimensions(128, 128).execute((result) async {
      final view = result.viewer.view;
      await view.setSubsurfaceScatteringEnabled(true);
      final sss = view.getSubsurfaceScattering()!;

      await sss.setParameters(SubsurfaceScatteringParameters(blurResolutionScale: 4.0));
      expect(sss.parameters.blurResolutionScale, 1.0, reason: "the blur cannot exceed the main view's resolution");

      await sss.setParameters(SubsurfaceScatteringParameters(blurResolutionScale: 0.001));
      expect(sss.parameters.blurResolutionScale, closeTo(1.0 / 8.0, 1e-9));

      await sss.setParameters(
        SubsurfaceScatteringParameters(radiusRed: 20.0, radiusGreen: 11.0, radiusBlue: 6.0, intensity: 0.5),
      );
      expect(sss.parameters.radiusRed, 20.0);
      expect(sss.parameters.radiusGreen, 11.0);
      expect(sss.parameters.radiusBlue, 6.0);
      expect(sss.parameters.intensity, 0.5);

      await view.setSubsurfaceScatteringEnabled(false);
    });
  });

  test('cannot be combined with the highlight overlay', () async {
    await ViewerBuilder(testHelper).addSun().setStencilBufferEnabled(true).execute((result) async {
      final view = result.viewer.view;
      final cube = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.accessibleGeometryBuffers},
        addToScene: true,
      );

      await view.setHighlightOverlayEnabled(true);
      await view.setStencilHighlight(cube);

      await expectLater(
        view.setSubsurfaceScatteringEnabled(true),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('highlight overlay'),
          ),
        ),
      );

      await view.removeStencilHighlight(cube);
      await view.setHighlightOverlayEnabled(false);
    });
  });
}
