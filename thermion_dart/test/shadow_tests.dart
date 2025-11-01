import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

Future<ThermionAsset> _createPlane(ThermionViewer viewer, {
  double width = 10.0,
  double height = 10.0,
  bool receiveShadows = true,
  bool castShadows = true,
  bool useUbershader = true,
}) async {
  
  final materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();
  await materialInstance.setCullingMode(CullingMode.NONE);
  await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);

  final plane = await viewer.createGeometry(
    GeometryHelper.plane(
      normals: true,
      uvs: true,
      width: width,
      height: height
    ),
    materialInstances: useUbershader ? [materialInstance] : []
  );

  await plane.setReceiveShadows(receiveShadows);
  await plane.setCastShadows(castShadows);
  return plane;
}

void main() async {
  final testHelper = TestHelper("material");
  await testHelper.setup();

  group("shadow tests", () {
    test('enable/disable shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setShadowsEnabled(false);
        await viewer.setShadowType(ShadowType.PCF);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await _createPlane(viewer);

        expect(await plane.isCastShadowsEnabled(), true);
        expect(await plane.isReceiveShadowsEnabled(), true);
        final materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setCullingMode(CullingMode.NONE);
        await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);
        await viewer.setShadowsEnabled(true);

        await testHelper.capture(viewer.view, "shadows_enabled");

        await viewer.setShadowsEnabled(false);

        await testHelper.capture(viewer.view, "shadows_disabled");
      }, bg: kRed, createRenderTarget: true, postProcessing: true);
    });

    test('enable/disable cast shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await _createPlane(viewer);

        final materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setCullingMode(CullingMode.NONE);
        await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);

        expect(await cube.isCastShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "cast_shadows_enabled");

        await cube.setCastShadows(false);
        expect(await cube.isCastShadowsEnabled(), false);
        await testHelper.capture(viewer.view, "cast_shadows_disabled");
      }, bg: kRed, createRenderTarget: true, postProcessing: true);
    });

    test('enable/disable receive shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await _createPlane(viewer);

        final materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await materialInstance.setCullingMode(CullingMode.NONE);
        await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);

        expect(await plane.isReceiveShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "receive_shadows_enabled");

        await plane.setReceiveShadows(false);
        expect(await plane.isReceiveShadowsEnabled(), false);
        await testHelper.capture(viewer.view, "receive_shadows_disabled");
      }, bg: kRed, createRenderTarget: true, postProcessing: true);
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
          .addPlane(receiveShadows: true).setShadowsEnabled(true);

      await builder.withViewer((viewer) async {

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
      await testHelper.withViewer((viewer) async {
        // Create a cube and add to scene
        var cube = await FilamentApp.instance!
            .createGeometry(GeometryHelper.cube(flipUvs: true), nullptr);
        await viewer.addToScene(cube);

        // Create a ground plane to see shadows
        var groundPlane = await _createPlane(viewer, useUbershader: false);
        await viewer.addToScene(groundPlane);

        // Position and scale the ground plane
        await FilamentApp.instance!.setTransform(
            groundPlane.entity,
            Matrix4.compose(
                Vector3(0, -1.5, 0), // Position below cube
                Quaternion.axisAngle(
                    Vector3(1, 0, 0), -3.14159 / 2), // Rotate to horizontal
                Vector3(10, 10, 1) // Scale up
                ));

        // Position camera
        final camera = await viewer.getActiveCamera();
        await camera.lookAt(Vector3(3, 4, 5), focus: Vector3.zero());

        // Add directional light (sun)
        final scene = await viewer.view.getScene();
        var light = await FilamentApp.instance!.createDirectLight(DirectLight(
            type: LightType.SUN,
            color: 6500,
            intensity: 100000,
            direction: Vector3(-0.5, -1, -0.5).normalized(),
            position: Vector3.zero()));
        await scene.addEntity(light);

        // Enable shadows and set shadow type to PCSS (supports soft shadows)
        await viewer.view.setShadowsEnabled(true);
        await viewer.view.setShadowType(ShadowType.PCSS);

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
      await testHelper.withViewer((viewer) async {
        // Create a cube and add to scene
        var cube = await FilamentApp.instance!
            .createGeometry(GeometryHelper.cube(flipUvs: true), nullptr);
        await viewer.addToScene(cube);

        // Create a ground plane to see shadows
        var groundPlane = await _createPlane(viewer, useUbershader: false);
        await viewer.addToScene(groundPlane);

        // Position and scale the ground plane
        await FilamentApp.instance!.setTransform(
            groundPlane.entity,
            Matrix4.compose(
                Vector3(0, -1.5, 0), // Position below cube
                Quaternion.axisAngle(
                    Vector3(1, 0, 0), -3.14159 / 2), // Rotate to horizontal
                Vector3(10, 10, 1) // Scale up
                ));

        // Position camera
        final camera = await viewer.getActiveCamera();
        await camera.lookAt(Vector3(3, 4, 5), focus: Vector3.zero());

        // Add directional light (sun)
        final scene = await viewer.view.getScene();
        var light = await FilamentApp.instance!.createDirectLight(DirectLight(
            type: LightType.SUN,
            color: 6500,
            intensity: 100000,
            direction: Vector3(-0.5, -1, -0.5).normalized(),
            position: Vector3.zero()));
        await scene.addEntity(light);

        // Capture with normal winding
        await viewer.view.setFrontFaceWindingInverted(false);
        await testHelper.capture(viewer.view, "front_face_winding_normal");

        // Capture with inverted winding (should show inside-out)
        await viewer.view.setFrontFaceWindingInverted(true);
        await testHelper.capture(viewer.view, "front_face_winding_inverted");
      });
    });

    test('ViewerBuilder example', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setPostProcessing(true)
          .setRenderTargetEnabled(true)
          .setShadowsEnabled(true)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized());

      await builder.withViewer((viewer) async {
        final materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setCullingMode(CullingMode.NONE);
        await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);

        expect(await cube.isCastShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "viewer_builder_example");
      });
    });

    test('ViewerBuilder withCube method', () async {
      final builder = ViewerBuilder(testHelper)
          .setBackgroundColor(kRed)
          .setRenderTargetEnabled(true)
          .setShadowsEnabled(true)
          .setShadowType(ShadowType.PCF)
          .addSun(
              intensity: 50000,
              castShadows: true,
              direction: Vector3(1, -0.5, 0).normalized());

      await builder.withCube((cube) async {
        expect(await cube.isCastShadowsEnabled(), true);
        await testHelper.capture(null, "viewer_builder_with_cube_example");
      });
    });
  });
}
