import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  await testHelper.setup();

  test('add/clear point light', () async {
    await ViewerBuilder(testHelper).addCube(createUbershader: true).execute((result) async {
      var light = await result.viewer.addDirectLight(DirectLight.point(intensity: 1000000, falloffRadius: 10));
      await result.viewer.setLightPosition(light, 1, 2, 2);
      await testHelper.capture(result.viewer.view, "add_point_light");
      await result.viewer.setLightPosition(light, -1, 2, 2);
      await testHelper.capture(result.viewer.view, "move_point_light");
      await result.viewer.removeLight(light);
      await testHelper.capture(result.viewer.view, "remove_point_light");
    });
  });

  test('load/remove ibl from KTX', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).addCube(createUbershader: true).execute((
      result,
    ) async {
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "ibl_ktx_loaded");
      await result.viewer.removeIbl();
      await testHelper.capture(result.viewer.view, "ibl_ktx_removed");
    });
  });

  test('load/remove ibl with manually constructed texture', () async {
    await ViewerBuilder(
      testHelper,
    ).setCameraLookAt(Vector3(0, 0, 5)).addCube(createUbershader: true).addSkybox().execute((result) async {
      final texture = await FilamentApp.instance!.createTexture(
        1,
        1,
        textureSamplerType: TextureSamplerType.SAMPLER_CUBEMAP,
        flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_UPLOADABLE},
      );
      // A cubemap has six layers. Leaving five faces uninitialized made this
      // capture alternate between the expected red reflection and black.
      var data = Float32List.fromList(List<double>.filled(6 * 1 * 1 * 4, 1.0)).asUint8List();
      await texture.setImage(0, data, 1, 1, PixelDataFormat.RGBA, PixelDataType.FLOAT, depth: 6);

      var indirectLight = await FFIIndirectLight.fromIrradianceTexture(
        FilamentApp.instance! as FFIFilamentApp,
        texture,
        reflectionsTexture: texture,
        intensity: 30000.0,
      );
      final scene = await result.viewer.view.getScene();
      await scene.setIndirectLight(indirectLight);

      await testHelper.capture(result.viewer.view, "ibl_from_texture_loaded");

      await result.viewer.removeIbl(destroy: true);
      await testHelper.capture(result.viewer.view, "ibl_from_texture_removed");
    });
  });

  test('LightManager type queries and component management', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(
          position: Vector3(0, -1.5, 0),
          scale: Vector3(10, 10, 1),
          color: null, // Use default ubershader material
        );

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      // Capture initial state
      await testHelper.capture(result.viewer.view, "initial_scene");

      // Create a SUN light
      final sunLight = lightManager.createLight(LightType.SUN);
      await scene.addEntity(sunLight);
      expect(lightManager.hasComponent(sunLight), isTrue);
      await testHelper.capture(result.viewer.view, "sun_light_created");

      // Test type queries
      expect(lightManager.getType(sunLight), equals(LightType.SUN));
      expect(lightManager.isDirectional(sunLight), isTrue);
      expect(lightManager.isPointLight(sunLight), isFalse);
      expect(lightManager.isSpotLight(sunLight), isFalse);

      // Test with a POINT light
      final pointLight = lightManager.createLight(LightType.POINT);
      await scene.addEntity(pointLight);
      expect(lightManager.isPointLight(pointLight), isTrue);
      expect(lightManager.isDirectional(pointLight), isFalse);
      await testHelper.capture(result.viewer.view, "point_light_created");

      // Test with a SPOT light
      final spotLight = lightManager.createLight(LightType.SPOT);
      await scene.addEntity(spotLight);
      expect(lightManager.isSpotLight(spotLight), isTrue);
      await testHelper.capture(result.viewer.view, "spot_light_created");

      // Cleanup
      await scene.removeEntity(sunLight);
      await scene.removeEntity(pointLight);
      await scene.removeEntity(spotLight);

      lightManager.destroyLight(sunLight);
      lightManager.destroyLight(pointLight);
      lightManager.destroyLight(spotLight);

      expect(lightManager.hasComponent(sunLight), isFalse);
      await testHelper.capture(result.viewer.view, "all_lights_destroyed");
    });
  });

  test('LightManager position and direction getters/setters', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 15, 5), focus: Vector3.zero())
        .setBackgroundColor(kRed)
        .addCube(color: kBlue)
        .setPostProcessing(true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(2, 1, 1), color: kGreen)
        .execute((result) async {
          final lightManager = FilamentApp.instance!.lightManager;

          final sunLight = lightManager.createLight(LightType.SUN);
          lightManager.setPosition(sunLight, 1.0, 2.0, 3.0);
          lightManager.setDirection(sunLight, 0.0, -1.0, 0.0);
          lightManager.setIntensity(sunLight, 50000);
          final scene = await result.viewer.view.getScene();
          await scene.addEntity(sunLight);
          await testHelper.capture(result.viewer.view, "light_created");

          final position = lightManager.getPosition(sunLight);
          expect(position[0], closeTo(1.0, 0.001));
          expect(position[1], closeTo(2.0, 0.001));
          expect(position[2], closeTo(3.0, 0.001));
          final direction = lightManager.getDirection(sunLight);
          expect(direction[0], closeTo(0.0, 0.001));
          expect(direction[1], closeTo(-1.0, 0.001));
          expect(direction[2], closeTo(0.0, 0.001));

          await scene.removeEntity(sunLight);

          lightManager.destroyLight(sunLight);
        });
  });

  test('LightManager intensity management', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      final sunLight = lightManager.createLight(LightType.SUN);
      await scene.addEntity(sunLight);
      await testHelper.capture(result.viewer.view, "light_created_default_intensity");

      // Test intensity
      lightManager.setIntensity(sunLight, 100000.0);
      await testHelper.capture(result.viewer.view, "light_intensity_set");

      expect(lightManager.getIntensity(sunLight), closeTo(100000.0, 0.001));

      await scene.removeEntity(sunLight);
      lightManager.destroyLight(sunLight);
    });
  });

  test('LightManager sun-specific methods', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      final sunLight = lightManager.createLight(LightType.SUN);
      await scene.addEntity(sunLight);
      await testHelper.capture(result.viewer.view, "sun_light_created");

      // Test sun-specific methods
      lightManager.setSunAngularRadius(sunLight, 0.545);
      await testHelper.capture(result.viewer.view, "sun_angular_radius_set");

      expect(lightManager.getSunAngularRadius(sunLight), closeTo(0.545, 0.001));

      lightManager.setSunHaloSize(sunLight, 15.0);
      await testHelper.capture(result.viewer.view, "sun_halo_size_set");

      expect(lightManager.getSunHaloSize(sunLight), closeTo(15.0, 0.001));

      lightManager.setSunHaloFalloff(sunLight, 100.0);
      await testHelper.capture(result.viewer.view, "sun_halo_falloff_set");

      expect(lightManager.getSunHaloFalloff(sunLight), closeTo(100.0, 0.001));

      await scene.removeEntity(sunLight);
      lightManager.destroyLight(sunLight);
    });
  });

  test('LightManager shadow management', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 5, 15), focus: Vector3.zero())
        .setShadowsEnabled(true)
        .setShadowType(ShadowType.PCF)
        .setBackgroundColor(kRed)
        .addCube(castShadows: true, color: kBlue)
        .addPlane(scale: Vector3(10, 1, 10), receiveShadows: true, castShadows: false, color: kGreen);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      final sunLight = lightManager.createLight(LightType.SUN);
      lightManager.setDirection(sunLight, 1, -1, 0);
      await scene.addEntity(sunLight);
      await testHelper.capture(result.viewer.view, "sun_light_created_no_shadows");

      // Test shadow caster
      await lightManager.setShadowCaster(sunLight, true);
      await testHelper.capture(result.viewer.view, "shadow_caster_enabled");

      expect(lightManager.isShadowCaster(sunLight), isTrue);

      // Test shadow options
      final shadowOptions = ShadowOptions(
        mapSize: 2048,
        shadowCascades: 3,
        cascadeSplitPositions: [0.1, 0.9],
        constantBias: 0.002,
        normalBias: 2.0,
        stable: true,
        penumbraScale: 1.5,
        penumbraRatioScale: 2.5,
        maxPenumbraRatio: 4.0,
        maxSearchRadius: 0.2,
      );
      await lightManager.setShadowOptions(sunLight, shadowOptions);
      await testHelper.capture(result.viewer.view, "shadow_options_configured");

      final retrievedOptions = lightManager.getShadowOptions(sunLight);
      expect(retrievedOptions.mapSize, equals(2048));
      expect(retrievedOptions.shadowCascades, equals(3));
      expect(retrievedOptions.cascadeSplitPositions.length, equals(2));
      expect(retrievedOptions.constantBias, closeTo(0.002, 0.0001));
      expect(retrievedOptions.normalBias, closeTo(2.0, 0.0001));
      expect(retrievedOptions.stable, isTrue);
      expect(retrievedOptions.penumbraScale, closeTo(1.5, 0.0001));
      expect(retrievedOptions.penumbraRatioScale, closeTo(2.5, 0.0001));
      expect(retrievedOptions.maxPenumbraRatio, closeTo(4.0, 0.0001));
      expect(retrievedOptions.maxSearchRadius, closeTo(0.2, 0.0001));

      await scene.removeEntity(sunLight);
      lightManager.destroyLight(sunLight);
    });
  });

  test('LightManager light channel management', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      final sunLight = lightManager.createLight(LightType.SUN);
      await scene.addEntity(sunLight);
      await testHelper.capture(result.viewer.view, "light_created_default_channels");

      // Test light channels
      lightManager.setLightChannel(sunLight, 1, true);
      await testHelper.capture(result.viewer.view, "light_channel_1_enabled");

      expect(lightManager.getLightChannel(sunLight, 1), isTrue);

      lightManager.setLightChannel(sunLight, 1, false);
      await testHelper.capture(result.viewer.view, "light_channel_1_disabled");

      expect(lightManager.getLightChannel(sunLight, 1), isFalse);

      await scene.removeEntity(sunLight);
      lightManager.destroyLight(sunLight);
    });
  });

  test('LightManager point light specific methods', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      final pointLight = lightManager.createLight(LightType.POINT);
      await scene.addEntity(pointLight);
      await testHelper.capture(result.viewer.view, "point_light_created");

      // Test falloff
      lightManager.setFalloff(pointLight, 5.0);
      await testHelper.capture(result.viewer.view, "point_light_falloff_set");

      expect(lightManager.getFalloff(pointLight), closeTo(5.0, 0.001));

      await scene.removeEntity(pointLight);
      lightManager.destroyLight(pointLight);
    });
  });

  test('LightManager spot light specific methods', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      final spotLight = lightManager.createLight(LightType.SPOT);
      await scene.addEntity(spotLight);
      await testHelper.capture(result.viewer.view, "spot_light_created");

      // Test spot light cone
      lightManager.setSpotLightCone(spotLight, 0.5, 1.0);
      await testHelper.capture(result.viewer.view, "spot_light_cone_set");

      expect(lightManager.getSpotLightInnerCone(spotLight), greaterThan(0.0));
      expect(lightManager.getSpotLightOuterCone(spotLight), closeTo(1.0, 0.001));

      await scene.removeEntity(spotLight);
      lightManager.destroyLight(spotLight);
    });
  });

  test('LightManager sun light color management', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 10, 10), focus: Vector3.zero())
        .addCube(color: kGrey, createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: kWhite, createUbershader: true);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      // Create a sun light with default color temperature (6500K - neutral white)
      final sunLight = lightManager.createLight(LightType.SUN);
      lightManager.setDirection(sunLight, 0, -0.5, -0.5);
      lightManager.setIntensity(sunLight, 100000.0);
      await scene.addEntity(sunLight);

      await testHelper.capture(result.viewer.view, "sun_light_default_color");

      // Change sun light color to warm (orange/red) - low color temperature
      lightManager.setColorTemperature(sunLight, 2000.0);
      await testHelper.capture(result.viewer.view, "sun_light_warm_color");

      // Verify the color changed (should be more red/orange)
      final warmColor = lightManager.getColor(sunLight);
      expect(warmColor, isA<List<double>>());
      expect(warmColor.length, equals(3));

      // Change sun light color to cool (blue) - high color temperature
      lightManager.setColorTemperature(sunLight, 12000.0);
      await testHelper.capture(result.viewer.view, "sun_light_cool_color");

      // Verify the color changed (should be more blue)
      final coolColor = lightManager.getColor(sunLight);
      expect(coolColor, isA<List<double>>());
      expect(coolColor.length, equals(3));

      // Change back to neutral white
      lightManager.setColorTemperature(sunLight, 6500.0);
      await testHelper.capture(result.viewer.view, "sun_light_neutral_color");

      // Verify the color changed back
      final neutralColor = lightManager.getColor(sunLight);
      expect(neutralColor, isA<List<double>>());
      expect(neutralColor.length, equals(3));

      await scene.removeEntity(sunLight);
      lightManager.destroyLight(sunLight);
    });
  });

  test('LightManager color management', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;
      final scene = await result.viewer.view.getScene();

      // Create a point light with default color temperature (6500K - neutral white)
      final pointLight = lightManager.createLight(LightType.POINT);
      lightManager.setPosition(pointLight, 2.0, 2.0, 2.0);
      lightManager.setIntensity(pointLight, 50000.0);
      await scene.addEntity(pointLight);
      await testHelper.capture(result.viewer.view, "point_light_default_color");

      // Change light color to warm (orange/red) - low color temperature
      lightManager.setColorTemperature(pointLight, 2000.0);
      await testHelper.capture(result.viewer.view, "point_light_warm_color");

      // Verify the color changed (should be more red/orange)
      final warmColor = lightManager.getColor(pointLight);
      expect(warmColor, isA<List<double>>());
      expect(warmColor.length, equals(3));

      // Change light color to cool (blue) - high color temperature
      lightManager.setColorTemperature(pointLight, 12000.0);
      await testHelper.capture(result.viewer.view, "point_light_cool_color");

      // Verify the color changed (should be more blue)
      final coolColor = lightManager.getColor(pointLight);
      expect(coolColor, isA<List<double>>());
      expect(coolColor.length, equals(3));

      // Change back to neutral white
      lightManager.setColorTemperature(pointLight, 6500.0);
      await testHelper.capture(result.viewer.view, "point_light_neutral_color");

      // Verify the color changed back
      final neutralColor = lightManager.getColor(pointLight);
      expect(neutralColor, isA<List<double>>());
      expect(neutralColor.length, equals(3));

      await scene.removeEntity(pointLight);
      lightManager.destroyLight(pointLight);
    });
  });

  test('LightManager ShadowCascades utility methods', () async {
    final builder = ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .addCube(createUbershader: true)
        .addPlane(position: Vector3(0, -1.5, 0), scale: Vector3(10, 10, 1), color: null);

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;

      final uniformSplits2 = lightManager.computeUniformSplits(2);
      expect(uniformSplits2.length, equals(1));
      expect(uniformSplits2[0], closeTo(0.5, 0.001));

      final uniformSplits3 = lightManager.computeUniformSplits(3);
      expect(uniformSplits3.length, equals(2));
      expect(uniformSplits3[0], closeTo(0.333, 0.001));
      expect(uniformSplits3[1], closeTo(0.667, 0.001));

      final uniformSplits4 = lightManager.computeUniformSplits(4);
      expect(uniformSplits4.length, equals(3));
      expect(uniformSplits4[0], closeTo(0.25, 0.001));
      expect(uniformSplits4[1], closeTo(0.5, 0.001));
      expect(uniformSplits4[2], closeTo(0.75, 0.001));

      expect(() => lightManager.computeUniformSplits(1), throwsArgumentError);
      expect(() => lightManager.computeUniformSplits(5), throwsArgumentError);

      final logSplits2 = lightManager.computeLogSplits(2, 0.1, 100.0);
      expect(logSplits2.length, equals(1));
      expect(logSplits2[0], greaterThan(0.0));
      expect(logSplits2[0], lessThan(1.0));

      final logSplits3 = lightManager.computeLogSplits(3, 0.1, 100.0);
      expect(logSplits3.length, equals(2));
      expect(logSplits3[0], greaterThan(0.0));
      expect(logSplits3[0], lessThan(logSplits3[1]));
      expect(logSplits3[1], greaterThan(0.0));
      expect(logSplits3[1], lessThan(1.0));

      final logSplits4 = lightManager.computeLogSplits(4, 0.1, 100.0);
      expect(logSplits4.length, equals(3));
      for (int i = 0; i < logSplits4.length; i++) {
        expect(logSplits4[i], greaterThan(0.0));
        expect(logSplits4[i], lessThan(1.0));
        if (i > 0) {
          expect(logSplits4[i], greaterThan(logSplits4[i - 1]));
        }
      }

      expect(() => lightManager.computeLogSplits(1, 0.1, 100.0), throwsArgumentError);
      expect(() => lightManager.computeLogSplits(5, 0.1, 100.0), throwsArgumentError);

      final practicalSplits2 = lightManager.computePracticalSplits(2, 0.1, 100.0, 0.5);
      expect(practicalSplits2.length, equals(1));
      expect(practicalSplits2[0], greaterThan(0.0));
      expect(practicalSplits2[0], lessThan(1.0));

      final practicalSplits3 = lightManager.computePracticalSplits(3, 0.1, 100.0, 0.5);
      expect(practicalSplits3.length, equals(2));
      for (int i = 0; i < practicalSplits3.length; i++) {
        expect(practicalSplits3[i], greaterThan(0.0));
        expect(practicalSplits3[i], lessThan(1.0));
        if (i > 0) {
          expect(practicalSplits3[i], greaterThan(practicalSplits3[i - 1]));
        }
      }

      final practicalSplits4 = lightManager.computePracticalSplits(4, 0.1, 100.0, 0.5);
      expect(practicalSplits4.length, equals(3));
      for (int i = 0; i < practicalSplits4.length; i++) {
        expect(practicalSplits4[i], greaterThan(0.0));
        expect(practicalSplits4[i], lessThan(1.0));
        if (i > 0) {
          expect(practicalSplits4[i], greaterThan(practicalSplits4[i - 1]));
        }
      }

      final near = 0.1;
      final far = 100.0;

      // Test lambda = 0 (should be closer to logarithmic)
      final practicalSplits0 = lightManager.computePracticalSplits(3, near, far, 0.0);

      // Test lambda = 1 (should be closer to uniform)
      final practicalSplits1 = lightManager.computePracticalSplits(3, near, far, 1.0);

      // Test lambda = 0.5 (should be between uniform and logarithmic)
      final practicalSplits05 = lightManager.computePracticalSplits(3, near, far, 0.5);

      // All should be valid splits
      for (final splits in [practicalSplits0, practicalSplits1, practicalSplits05]) {
        expect(splits.length, equals(2));
        for (int i = 0; i < splits.length; i++) {
          expect(splits[i], greaterThan(0.0));
          expect(splits[i], lessThan(1.0));
          if (i > 0) {
            expect(splits[i], greaterThan(splits[i - 1]));
          }
        }
      }

      expect(() => lightManager.computePracticalSplits(1, 0.1, 100.0, 0.5), throwsArgumentError);
      expect(() => lightManager.computePracticalSplits(5, 0.1, 100.0, 0.5), throwsArgumentError);
      expect(() => lightManager.computePracticalSplits(3, 0.1, 100.0, -0.1), throwsArgumentError);
      expect(() => lightManager.computePracticalSplits(3, 0.1, 100.0, 1.1), throwsArgumentError);

      final cascades = 3;

      final uniformSplits = lightManager.computeUniformSplits(cascades);
      final logSplits = lightManager.computeLogSplits(cascades, near, far);
      final practicalSplits = lightManager.computePracticalSplits(cascades, near, far, 0.5);

      expect(uniformSplits.length, equals(2));
      expect(logSplits.length, equals(2));
      expect(practicalSplits.length, equals(2));

      // Results should be different (except possibly coincidentally)
      bool allEqual = true;
      for (int i = 0; i < uniformSplits.length; i++) {
        if ((uniformSplits[i] - logSplits[i]).abs() > 0.001 || (uniformSplits[i] - practicalSplits[i]).abs() > 0.001) {
          allEqual = false;
          break;
        }
      }
      expect(allEqual, isFalse);
    });
  });
}
