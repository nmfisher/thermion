@Timeout(const Duration(seconds: 600))
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  Logger.root.onRecord.listen((record) {
    print(record);
  });

  final testHelper = TestHelper("color_grading_builder");
  await testHelper.setup();

  test('all available ToneMappers', () async {
    // Test all available ToneMapper factory methods using ViewerBuilder
    final toneMappers = [
      () => ToneMapper.linear(FilamentApp.instance!),
      'linear',
      () => ToneMapper.aces(FilamentApp.instance!),
      'aces',
      () => ToneMapper.acesLegacy(FilamentApp.instance!),
      'aces_legacy',
      () => ToneMapper.filmic(FilamentApp.instance!),
      'filmic',
      () => ToneMapper.pbrNeutral(FilamentApp.instance!),
      'pbr_neutral',
      () => ToneMapper.agx(FilamentApp.instance!),
      'agx_none',
      () => ToneMapper.agx(FilamentApp.instance!, look: AgxLook.punchy),
      'agx_punchy',
      () => ToneMapper.agx(FilamentApp.instance!, look: AgxLook.golden),
      'agx_golden',
      () => ToneMapper.generic(FilamentApp.instance!),
      'generic_default',
      () => ToneMapper.generic(FilamentApp.instance!, contrast: 2.0),
      'generic_contrast_2_0',
      () => ToneMapper.displayRange(FilamentApp.instance!),
      'display_range',
    ];

    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 2, 8), focus: Vector3.zero())
        .setPostProcessing(true)
        .addSun(
          intensity: 110000,
          castShadows: true,
          direction: Vector3(0.7, -1, -0.8).normalized(),
          sunAngularRadius: 1.9,
        )
        .addCube(color: kWhite, createUbershader: true)
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          color: kWhite,
          createUbershader: true,
        )
        .execute((result) async {
          for (int i = 0; i < toneMappers.length; i += 2) {
            final toneMapperFactory = toneMappers[i] as Future<ToneMapper> Function();
            final name = toneMappers[i + 1] as String;
            final toneMapper = await toneMapperFactory();

            // Apply the tone mapper via the color grading builder
            final builder = await result.viewer.view.createColorGradingBuilder();
            final colorGrading = await builder.toneMapper(toneMapper).build();
            // done building: dispose the builder, then the mapper it referenced
            await builder.dispose();
            await toneMapper.dispose();
            await result.viewer.view.setColorGrading(colorGrading);

            // Capture the viewport after changing tone mapper
            await testHelper.capture(result.viewer.view, "tone_mapper_$name");

            // The grading is caller-owned: dissociate, then dispose
            await result.viewer.view.setColorGrading(null);
            await colorGrading.dispose();
          }
        });
  });

  test('ColorGrading builder', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 2, 8), focus: Vector3.zero())
        .setPostProcessing(true)
        .addCube(color: kWhite, createUbershader: true)
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          color: kWhite,
          createUbershader: true,
        )
        .execute((result) async {
          // Create a complex color grading using the builder
          final builder = await result.viewer.view.createColorGradingBuilder();
          final toneMapper = await ToneMapper.aces(FilamentApp.instance!);
          final colorGrading = await builder
              .quality(QualityLevel.HIGH)
              .exposure(0.7) // Slight exposure adjustment
              .whiteBalance(0.1, -0.05) // Slight warm tint
              .contrast(1.15) // Moderate contrast boost
              .vibrance(1.1) // Slight vibrance boost
              .saturation(0.95) // Slight desaturation
              .luminanceScaling(true) // Better HDR handling
              .gamutMapping(true) // Prevent hue shifts
              .toneMapper(toneMapper) // Add a tone mapper
              .shadowsMidtonesHighlights(
                Vector4(0.8, 0.9, 1.0, 0.5), // Slightly cool shadows
                Vector4(1.0, 1.0, 1.0, 1.0), // Neutral midtones
                Vector4(1.1, 1.05, 1.0, 0.5), // Slightly warm highlights
                Vector4(0.2, 0.5, 0.8, 1.0), // Transition ranges
              )
              .build();

          expect(colorGrading, isNotNull);

          // The builder is reusable (Filament's pattern): change a setting
          // and build again to get an independent grading.
          final brighterColorGrading = await builder.exposure(2.0).build();

          // Done building: dispose the builder, then the mapper it referenced
          await builder.dispose();
          await toneMapper.dispose();

          // Apply the color grading to the view
          await result.viewer.view.setColorGrading(colorGrading);

          // Capture the viewport after applying color grading
          await testHelper.capture(result.viewer.view, "color_grading_builder_applied");

          // Attaching the second grading dissociates the first, so the first
          // can now be disposed (caller-owned lifecycle)
          await result.viewer.view.setColorGrading(brighterColorGrading);
          await colorGrading.dispose();
          await testHelper.capture(result.viewer.view, "color_grading_builder_rebuilt_brighter");

          // Dissociate, then dispose the second grading
          await result.viewer.view.setColorGrading(null);
          await brighterColorGrading.dispose();
        });
  });

  test('ColorGrading LUT format and dimensions', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 2, 8), focus: Vector3.zero())
        .setPostProcessing(true)
        .addCube(color: kWhite, createUbershader: true)
        .addSun()
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          color: kWhite,
          createUbershader: true,
        )
        .execute((result) async {
          await testHelper.capture(result.viewer.view, "color_grading_lut_none");
          final configs = [
            (LutFormat.INTEGER, 16, 'integer_16'),
            (LutFormat.INTEGER, 32, 'integer_32'),
            (LutFormat.FLOAT, 32, 'float_32'),
            (LutFormat.FLOAT, 64, 'float_64'),
          ];

          for (final (format, dim, name) in configs) {
            final builder = await result.viewer.view.createColorGradingBuilder();
            final toneMapper = await ToneMapper.aces(FilamentApp.instance!);
            final colorGrading = await builder
                .format(format)
                .dimensions(dim)
                .toneMapper(toneMapper)
                .saturation(1.3)
                .contrast(1.2)
                .build();
            // done building: dispose the builder, then the mapper it referenced
            await builder.dispose();
            await toneMapper.dispose();

            expect(colorGrading, isNotNull);
            await result.viewer.view.setColorGrading(colorGrading);
            await testHelper.capture(result.viewer.view, "color_grading_lut_$name");

            // The grading is caller-owned: dissociate, then dispose
            await result.viewer.view.setColorGrading(null);
            await colorGrading.dispose();
          }
        });
  });

  test('ColorGrading channelMixer', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 2, 8), focus: Vector3.zero())
        .setPostProcessing(true)
        .addSun()
        .addCube(color: kRed, createUbershader: true)
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          color: kGreen,
          createUbershader: true,
        )
        .execute((result) async {
          final configs = <(Vector3, Vector3, Vector3, String)>[
            (Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), 'identity'),
            (Vector3(0.393, 0.769, 0.189), Vector3(0.349, 0.686, 0.168), Vector3(0.272, 0.534, 0.131), 'sepia'),
            (Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0), 'swap_rb'),
            (Vector3(0.299, 0.587, 0.114), Vector3(0.299, 0.587, 0.114), Vector3(0.299, 0.587, 0.114), 'luminance'),
          ];

          for (final (outRed, outGreen, outBlue, name) in configs) {
            final builder = await result.viewer.view.createColorGradingBuilder();
            final toneMapper = await ToneMapper.linear(FilamentApp.instance!);
            final colorGrading = await builder.toneMapper(toneMapper).channelMixer(outRed, outGreen, outBlue).build();
            // done building: dispose the builder, then the mapper it referenced
            await builder.dispose();
            await toneMapper.dispose();

            expect(colorGrading, isNotNull);
            await result.viewer.view.setColorGrading(colorGrading);
            await testHelper.capture(result.viewer.view, "color_grading_channel_mixer_$name");

            // The grading is caller-owned: dissociate, then dispose
            await result.viewer.view.setColorGrading(null);
            await colorGrading.dispose();
          }
        });
  });

  test('ColorGrading shared between views', () async {
    await ViewerBuilder(testHelper).setPostProcessing(true).addCube(color: kWhite, createUbershader: true).execute((
      result,
    ) async {
      final app = FilamentApp.instance!;
      final view1 = result.viewer.view;
      final view2 = await app.createView();
      await view2.setViewport(512, 512);
      try {
        final builder = await view1.createColorGradingBuilder();
        final toneMapper = await ToneMapper.aces(FilamentApp.instance!);
        final shared = await builder.toneMapper(toneMapper).saturation(2.0).build();
        await builder.dispose();
        await toneMapper.dispose();

        // One grading, two views - Filament allows this. Lifetime is the
        // caller's responsibility: neither view destroys or releases it.
        await view1.setColorGrading(shared);
        await view2.setColorGrading(shared);
        await testHelper.capture(view2, "color_grading_shared_view2");

        // Detaching view1 leaves the grading untouched (view2 still uses
        // it) - the caller, not the view, decides when it is destroyed
        await view1.setColorGrading(null);
        await testHelper.capture(view2, "color_grading_shared_view2_after_detach");

        // Dissociate from the last view, then dispose
        await view2.setColorGrading(null);
        await shared.dispose();
      } finally {
        await app.destroyView(view2);
      }
    });
  });

  test('ColorGrading dispose is idempotent', () async {
    await ViewerBuilder(testHelper).setPostProcessing(true).addCube(color: kWhite, createUbershader: true).execute((
      result,
    ) async {
      final view = result.viewer.view;
      final builder = await view.createColorGradingBuilder();
      final toneMapper = await ToneMapper.aces(FilamentApp.instance!);
      final colorGrading = await builder.toneMapper(toneMapper).build();
      await builder.dispose();
      await toneMapper.dispose();

      // Dissociate, then dispose - twice; the second is a no-op
      await view.setColorGrading(null);
      await colorGrading.dispose();
      await colorGrading.dispose();
    });
  });

  test('ColorGrading builder can be disposed without building', () async {
    await ViewerBuilder(testHelper).setPostProcessing(true).addCube(color: kWhite, createUbershader: true).execute((
      result,
    ) async {
      final builder = await result.viewer.view.createColorGradingBuilder();
      await builder.exposure(1.5);

      // Abandoning a builder without building must not leak: dispose it.
      await builder.dispose();
      // A second dispose is a no-op
      await builder.dispose();
      // Using a disposed builder throws
      expect(() => builder.exposure(1.0), throwsStateError);
      await expectLater(builder.build(), throwsStateError);

      // Tone mapper dispose is also idempotent
      final toneMapper = await ToneMapper.linear(FilamentApp.instance!);
      await toneMapper.dispose();
      await toneMapper.dispose();
    });
  });

  test('getColorGrading - retrieve and verify color grading', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 2, 8), focus: Vector3.zero())
        .setPostProcessing(true)
        .addCube(color: kWhite, createUbershader: true)
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          color: kWhite,
          createUbershader: true,
        )
        .execute((result) async {
          // Setting the color grading to null will clear the color grading
          await result.viewer.view.setColorGrading(null);
          // but internally, View resets this to a "default" color grading,
          // so this will be non-null. This is a non-owning wrapper around
          // Filament's internal default - never dispose it.
          var initialColorGrading = await result.viewer.view.getColorGrading();
          expect(initialColorGrading, isNotNull);

          // Create and apply a color grading
          final builder = await result.viewer.view.createColorGradingBuilder();
          final toneMapper = await ToneMapper.aces(FilamentApp.instance!);
          final colorGrading = await builder
              .quality(QualityLevel.HIGH)
              .exposure(0.5)
              .contrast(1.2)
              .saturation(1.1)
              .toneMapper(toneMapper)
              .build();
          await builder.dispose();
          await toneMapper.dispose();

          // Apply the color grading to the view
          await result.viewer.view.setColorGrading(colorGrading);

          // Retrieve the color grading from the view. This wraps the same
          // native grading as [colorGrading] - a non-owning view of it, not a
          // separate object to dispose.
          var retrievedColorGrading = await result.viewer.view.getColorGrading();
          expect(retrievedColorGrading, isNotNull);
          expect(retrievedColorGrading, isA<ColorGrading>());

          // Capture the viewport with color grading applied
          await testHelper.capture(result.viewer.view, "color_grading_get_test");

          // Clear the color grading by passing null. This only dissociates -
          // it does NOT destroy the grading, so dispose it explicitly.
          await result.viewer.view.setColorGrading(null);
          await colorGrading.dispose();

          // Capture the viewport with color grading cleared
          await testHelper.capture(result.viewer.view, "color_grading_cleared");
        });
  });
}
