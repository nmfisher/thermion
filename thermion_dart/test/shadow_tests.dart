import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("shadows");
  await testHelper.setup();

  test('toggle cast/receive shadows', () async {
    final builder = ViewerBuilder(testHelper)
        .setBackgroundColor(kRed)
        .setPostProcessing(true)
        .setRenderTargetEnabled(true)
        .setShadowsEnabled(true)
        .addSun(
          intensity: 50000,
          castShadows: true,
          direction: Vector3(1, -0.5, 0).normalized(),
        )
        .addPlane(receiveShadows: true, createUbershader: true)
        .addCube(castShadows: true, createUbershader: true);

    await builder.execute((result) async {
      final plane = result.assets[0];
      final cube = result.assets[1];

      expect(await plane.isReceiveShadowsEnabled(), true);
      expect(await cube.isCastShadowsEnabled(), true);

      await testHelper.capture(result.viewer.view, "cast_and_receive_shadows");

      await plane.setReceiveShadows(false);
      expect(await plane.isReceiveShadowsEnabled(), false);
      await testHelper.capture(result.viewer.view, "cast_noreceive_shadows");

      await plane.setReceiveShadows(true);
      await cube.setCastShadows(false);
      expect(await plane.isReceiveShadowsEnabled(), true);
      expect(await cube.isCastShadowsEnabled(), false);
      await testHelper.capture(result.viewer.view, "nocast_receive_shadows");
    });
  });

  test(
    'setShadowsEnabled with circular camera movement and changing sun direction',
    () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(false)
          .setShadowType(ShadowType.PCF)
          .addSun(
            intensity: 100000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized(),
          )
          .addCube(castShadows: true)
          .addPlane(
            receiveShadows: true,
            castShadows: true,
            createUbershader: true,
          )
          .execute((result) async {
        final plane = result.assets[1]; // The plane is the first asset
        final camera = await result.viewer.getActiveCamera();

        expect(await plane.isCastShadowsEnabled(), true);
        expect(await plane.isReceiveShadowsEnabled(), true);

        await result.viewer.setShadowsEnabled(true);

        // Move camera in 8 positions around a circle
        final int numPositions = 8;

        for (int i = 0; i < numPositions; i++) {
          final double angle = (i * 2 * pi) / numPositions;

          // Change sun direction based on camera position
          // Sun will rotate around the scene, always pointing towards the center from a slightly elevated angle
          final double sunAngle = angle + pi; // Sun opposite to camera position
          final double sunX = sin(sunAngle) * 0.7;
          final double sunY = -0.5; // Sun pointing downward
          final double sunZ = cos(sunAngle) * 0.7;
          final Vector3 sunDirection = Vector3(
            sunX,
            sunY,
            sunZ,
          ).normalized();

          // Update sun direction
          await result.viewer.setLightDirection(result.sun!, sunDirection);

          // Capture the view from this position
          await testHelper.capture(
            result.viewer.view,
            "shadows_circular_sun_pos_$i",
          );
        }
      });
    },
  );

  test('set shadow type', () async {
    // Create a builder with shadow setup and include render target
    final builder = ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .addSun(
          intensity: 100000,
          castShadows: true,
          direction: Vector3(1, -1, 0).normalized(),
        )
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(color: kRed, castShadows: true)
        .addPlane(receiveShadows: true)
        .setShadowsEnabled(true);

    await builder.execute((result) async {
      await testHelper.capture(result.viewer.view, "shadow_type_default");

      // Test different shadow types and capture each
      await result.viewer.view.setShadowType(ShadowType.PCF);
      await testHelper.capture(result.viewer.view, "shadow_type_pcf");

      await result.viewer.view.setShadowType(ShadowType.VSM);
      await testHelper.capture(result.viewer.view, "shadow_type_vsm");

      await result.viewer.view.setShadowType(ShadowType.DPCF);
      await testHelper.capture(result.viewer.view, "shadow_type_dpcf");

      await result.viewer.view.setShadowType(ShadowType.PCSS);
      await testHelper.capture(result.viewer.view, "shadow_type_pcss");
    });
  });

  test('set soft shadow options', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .setShadowsEnabled(true)
        .setShadowType(ShadowType.PCSS)
        .addSun(
          intensity: 100000,
          castShadows: true,
          direction: Vector3(-0.5, -1, -0.5).normalized(),
        )
        .addCube()
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          receiveShadows: true,
          castShadows: false,
          color: null, // Use default ubershader material
        );

    await builder.execute((result) async {
      // Test different soft shadow options and capture each
      await result.viewer.view.setSoftShadowOptions(
        SoftShadowOptions(penumbraScale: 0.1, penumbraRatioScale: 0.1),
      );
      await testHelper.capture(result.viewer.view, "soft_shadow_options_0.1");

      await result.viewer.view.setSoftShadowOptions(
        SoftShadowOptions(penumbraScale: 0.5, penumbraRatioScale: 0.5),
      );
      await testHelper.capture(result.viewer.view, "soft_shadow_options_0.5");

      await result.viewer.view.setSoftShadowOptions(
        SoftShadowOptions(penumbraScale: 1, penumbraRatioScale: 1),
      );
      await testHelper.capture(result.viewer.view, "soft_shadow_options_1.0");
    });
  });

  test('set front face winding inverted', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addSun(
          intensity: 100000,
          castShadows: true,
          direction: Vector3(-0.5, -1, -0.5).normalized(),
        )
        .addCube()
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          receiveShadows: true,
          castShadows: false,
          color: null, // Use default ubershader material
        );

    await builder.execute((result) async {
      // Capture with normal winding
      await result.viewer.view.setFrontFaceWindingInverted(false);
      await testHelper.capture(result.viewer.view, "front_face_winding_normal");

      // Capture with inverted winding (should show inside-out)
      await result.viewer.view.setFrontFaceWindingInverted(true);
      await testHelper.capture(
        result.viewer.view,
        "front_face_winding_inverted",
      );
    });
  });
}
