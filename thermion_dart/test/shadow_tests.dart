import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");
  await testHelper.setup();

  group("shadow tests", () {
    test('viewer setShadowsEnabled', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(true)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized())
          .addCube()
          .addPlane(receiveShadows: true, castShadows: true);

      await builder.execute((viewer, assets) async {
        final plane = assets[0]; // The plane is the first asset

        expect(await plane.isCastShadowsEnabled(), true);
        expect(await plane.isReceiveShadowsEnabled(), true);

        await viewer.setShadowsEnabled(true);
        await testHelper.capture(viewer.view, "shadows_enabled");

        await viewer.setShadowsEnabled(false);
        await testHelper.capture(viewer.view, "shadows_disabled");
      });
    });

    test('viewer setShadowsEnabled with circular camera movement', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(false)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized())
          .addCube()
          .addPlane(receiveShadows: true, castShadows: true);

      await builder.execute((viewer, assets) async {
        final plane = assets[0]; // The plane is the first asset
        final camera = await viewer.getActiveCamera();

        expect(await plane.isCastShadowsEnabled(), true);
        expect(await plane.isReceiveShadowsEnabled(), true);

        await viewer.setShadowsEnabled(true);

        // Move camera in 8 positions around a circle
        final int numPositions = 8;
        final double radius = 5.0;
        final double cameraHeight = 4.0;

        for (int i = 0; i < numPositions; i++) {
          // Calculate angle for this position (45-degree intervals)
          final double angle = (i * 2 * pi) / numPositions;

          // Calculate camera position on circle
          final double x = sin(angle) * radius;
          final double z = cos(angle) * radius;
          final Vector3 cameraPosition = Vector3(x, cameraHeight, z);

          // Move camera to this position, looking at origin
          await camera.lookAt(cameraPosition, focus: Vector3.zero());

          // Capture the view from this position
          await testHelper.capture(viewer.view, "shadows_circular_pos_$i");
        }
      });
    });

    test('viewer setShadowsEnabled with circular camera movement and changing sun direction', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(false)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized())
          .addCube()
          .addPlane(receiveShadows: true, castShadows: true);

      await builder.execute((viewer, assets) async {
        final plane = assets[0]; // The plane is the first asset
        final camera = await viewer.getActiveCamera();

        expect(await plane.isCastShadowsEnabled(), true);
        expect(await plane.isReceiveShadowsEnabled(), true);

        await viewer.setShadowsEnabled(true);

        // Get the sun light entity (the first direct light)
        // Note: Since we use addSun in the builder, we need to access it through the scene
        // For this test, we'll create the sun manually so we have access to the entity
        final sunLight = await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        // Move camera in 8 positions around a circle
        final int numPositions = 8;
        final double radius = 5.0;
        final double cameraHeight = 4.0;

        for (int i = 0; i < numPositions; i++) {
          // Calculate angle for this position (45-degree intervals)
          final double angle = (i * 2 * pi) / numPositions;

          // Calculate camera position on circle
          final double x = sin(angle) * radius;
          final double z = cos(angle) * radius;
          final Vector3 cameraPosition = Vector3(x, cameraHeight, z);

          // Move camera to this position, looking at origin
          await camera.lookAt(cameraPosition, focus: Vector3.zero());

          // Change sun direction based on camera position
          // Sun will rotate around the scene, always pointing towards the center from a slightly elevated angle
          final double sunAngle = angle + pi; // Sun opposite to camera position
          final double sunX = sin(sunAngle) * 0.7;
          final double sunY = -0.5; // Sun pointing downward
          final double sunZ = cos(sunAngle) * 0.7;
          final Vector3 sunDirection = Vector3(sunX, sunY, sunZ).normalized();

          // Update sun direction
          await viewer.setLightDirection(sunLight, sunDirection);

          // Capture the view from this position
          await testHelper.capture(viewer.view, "shadows_circular_sun_pos_$i");
        }

        // Clean up the manually created sun light
        await viewer.removeLight(sunLight);
      });
    });

    test('enable/disable cast shadows', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(true)
          .setShadowsEnabled(true)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized())
          .addPlane(receiveShadows: true)
          .addCube(castShadows: true);

      await builder.execute((viewer, assets) async {
        // Assets are returned in order: planes first, then cubes
        // So the cube should be the second asset (index 1)
        final cube = assets[1];

        expect(await cube.isCastShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "cast_shadows_enabled");

        await cube.setCastShadows(false);
        expect(await cube.isCastShadowsEnabled(), false);
        await testHelper.capture(viewer.view, "cast_shadows_disabled");
      });
    });

    test('enable/disable receive shadows', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(true)
          .setShadowsEnabled(true)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized())
          .addCube()
          .addPlane(receiveShadows: true, castShadows: true);

      await builder.execute((viewer, assets) async {
        // The plane is the first asset (index 0)
        final plane = assets[0];

        expect(await plane.isReceiveShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "receive_shadows_enabled");

        await plane.setReceiveShadows(false);
        expect(await plane.isReceiveShadowsEnabled(), false);
        await testHelper.capture(viewer.view, "receive_shadows_disabled");
      });
    });

    test('set shadow type', () async {
      // Create a builder with shadow setup and include render target
      final builder = ViewerBuilder(testHelper)
          .setRenderTargetEnabled(true)
          .addSun(
              intensity: 100000,
              castShadows: true,
              color: 6500,
              direction: Vector3(1, -1, 0).normalized())
          .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
          .addCube(color: kRed, castShadows: true)
          .addPlane(receiveShadows: true)
          .setShadowsEnabled(true);

      await builder.execute((viewer, assets) async {
        await testHelper.capture(viewer.view, "shadow_type_default");

        // Test different shadow types and capture each
        await viewer.view.setShadowType(ShadowType.PCF);
        await testHelper.capture(viewer.view, "shadow_type_pcf");

        await viewer.view.setShadowType(ShadowType.VSM);
        await testHelper.capture(viewer.view, "shadow_type_vsm");

        await viewer.view.setShadowType(ShadowType.DPCF);
        await testHelper.capture(viewer.view, "shadow_type_dpcf");

        await viewer.view.setShadowType(ShadowType.PCSS);
        await testHelper.capture(viewer.view, "shadow_type_pcss");
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
              color: 6500,
              direction: Vector3(-0.5, -1, -0.5).normalized())
          .addCube()
          .addPlane(
              position: Vector3(0, -1.5, 0),
              rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
              scale: Vector3(10, 10, 1),
              receiveShadows: true,
              castShadows: false,
              color: null // Use default ubershader material
          );

      await builder.execute((viewer, assets) async {
        // Test different soft shadow options and capture each
        await viewer.view.setSoftShadowOptions(0.1, 0.1);
        await testHelper.capture(viewer.view, "soft_shadow_options_0.1");

        await viewer.view.setSoftShadowOptions(0.5, 0.5);
        await testHelper.capture(viewer.view, "soft_shadow_options_0.5");

        await viewer.view.setSoftShadowOptions(1.0, 1.0);
        await testHelper.capture(viewer.view, "soft_shadow_options_1.0");
      });
    });

    test('set front face winding inverted', () async {
      final builder = ViewerBuilder(testHelper)
          .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
          .addSun(
              intensity: 100000,
              castShadows: true,
              color: 6500,
              direction: Vector3(-0.5, -1, -0.5).normalized())
          .addCube()
          .addPlane(
              position: Vector3(0, -1.5, 0),
              rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
              scale: Vector3(10, 10, 1),
              receiveShadows: true,
              castShadows: false,
              color: null // Use default ubershader material
          );

      await builder.execute((viewer, assets) async {
        // Capture with normal winding
        await viewer.view.setFrontFaceWindingInverted(false);
        await testHelper.capture(viewer.view, "front_face_winding_normal");

        // Capture with inverted winding (should show inside-out)
        await viewer.view.setFrontFaceWindingInverted(true);
        await testHelper.capture(viewer.view, "front_face_winding_inverted");
      });
    });
  });
}
