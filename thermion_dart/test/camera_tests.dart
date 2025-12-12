// ignore_for_file: unused_local_variable
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("camera");
  await testHelper.setup();

  test('create and destroy camera', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.createCamera();
      await camera.destroy();
    });
  });

  test('create and destroy camera for target entity', () async {
    final entity = await FilamentApp.instance!.createEntity();
    final camera =
        await FilamentApp.instance!.createCamera(targetEntity: entity);
    await camera.setModelMatrix(Matrix4.translation(Vector3(0, 0, 10)));
    var modelMatrix = await camera.getModelMatrix();
    expect(modelMatrix.getColumn(3).z, 10);
    await camera.destroy();
  });

  test('set model matrix', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.setModelMatrix(Matrix4.translation(Vector3.all(4.0)));
      var matrix = await camera.getModelMatrix();

      await camera.lookAt(Vector3(2.0, 2.0, 2.0));
      matrix = await camera.getModelMatrix();
      var position = await camera.getPosition();
      expect(position.x, 2.0);
      expect(position.y, 2.0);
      expect(position.z, 2.0);
    });
  });

  test('get/set exposure (aperture, shutter speed, sensitivity)', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();

      // Default exposure values should be f/16, 1/125s, 100 ISO
      var aperture = await camera.getAperture();
      var shutterSpeed = await camera.getShutterSpeed();
      var sensitivity = await camera.getSensitivity();

      expect(aperture, closeTo(16.0, 0.001));
      expect(shutterSpeed, closeTo(1.0 / 125.0, 0.00001));
      expect(sensitivity, closeTo(100.0, 0.001));

      await testHelper.capture(viewer.view, "camera_default_exposure");

      // Test setting and getting custom exposure parameters
      await camera.setExposure(16.0, 1.0 / 125.0, 200.0);

      aperture = await camera.getAperture();
      shutterSpeed = await camera.getShutterSpeed();
      sensitivity = await camera.getSensitivity();

      expect(aperture, closeTo(16.0, 0.001));
      expect(shutterSpeed, closeTo(1.0 / 125.0, 0.00001));
      expect(sensitivity, closeTo(200.0, 0.001));

      await testHelper.capture(viewer.view, "camera_iso_200");
    }, addSkybox: true);
  });

  // test('getCameraViewMatrix', () async {
  //   await testHelper.withViewer((viewer) async {
  //     await viewer.setCameraModelMatrix4(Matrix4.identity());
  //     var modelMatrix = await camera.getModelMatrix();
  //     var viewMatrix = await viewer.getCameraViewMatrix();

  //     // The view matrix should be the inverse of the model matrix
  //     var identity = modelMatrix * viewMatrix;
  //     expect(identity.isIdentity(), isTrue);
  //     var camera = await viewer.getMainCamera();
  //     identity = modelMatrix * (await camera.getViewMatrix());
  //     expect(identity.isIdentity(), isTrue);

  //     // Check that moving the camera affects the view matrix
  //     await viewer.setCameraPosition(3.0, 4.0, 5.0);
  //     viewMatrix = await viewer.getCameraViewMatrix();
  //     var invertedView = viewMatrix.clone()..invert();
  //     var position = invertedView.getColumn(3).xyz;
  //     expect(position.x, closeTo(3.0, 1e-6));
  //     expect(position.y, closeTo(4.0, 1e-6));
  //     expect(position.z, closeTo(5.0, 1e-6));
  //   });
  // });

  test('getCameraProjectionMatrix', () async {
    await testHelper.withViewer((viewer) async {
      var camera = await viewer.getActiveCamera();
      var projectionMatrix = await camera.getProjectionMatrix();
      print(projectionMatrix);
    });
  });

  test('getCameraCullingProjectionMatrix', () async {
    await testHelper.withViewer((viewer) async {
      var camera = await viewer.getActiveCamera();
      var matrix = await camera.getCullingProjectionMatrix();
      print(matrix);
    });
  });

  test('camera frustum', () async {
    await testHelper.withViewer((viewer) async {
      var camera = await viewer.getActiveCamera();
      var frustum = await camera.getFrustum();

      // Test that points in front of the camera are inside the frustum
      final nearPoint = Vector3(0, 0, -5);  // Point in front of camera
      final farPoint = Vector3(0, 0, -100); // Far point in front
      final leftPoint = Vector3(-5, 0, -10); // Left side
      final rightPoint = Vector3(5, 0, -10); // Right side
      final topPoint = Vector3(0, 5, -10); // Top
      final bottomPoint = Vector3(0, -5, -10); // Bottom

      // These should be inside the frustum
      expect(frustum.containsVector3(nearPoint), isTrue);
      expect(frustum.containsVector3(farPoint), isTrue);
      expect(frustum.containsVector3(leftPoint), isTrue);
      expect(frustum.containsVector3(rightPoint), isTrue);
      expect(frustum.containsVector3(topPoint), isTrue);
      expect(frustum.containsVector3(bottomPoint), isTrue);

      // Test point behind camera (should be outside)
      final behindPoint = Vector3(0, 0, 1); // Behind camera
      expect(frustum.containsVector3(behindPoint), isFalse);

    });
  });

  test('set orthographic projection', () async {
    await testHelper.withViewer((viewer) async {
      var camera = await viewer.getActiveCamera();

      await viewer.createGeometry(GeometryHelper.cube());

      await camera.setProjection(
          Projection.Orthographic, -0.05, 0.05, -0.05, 0.05, 0.05, 10000);
      await testHelper.capture(
          viewer.view, "camera_set_orthographic_projection");
    });
  });

  test('set perspective projection/culling matrix', () async {
    await testHelper.withViewer((viewer) async {
      var camera = await viewer.getActiveCamera();
      final cube = await viewer.createGeometry(GeometryHelper.cube());

      var fovY = pi / 2;
      await camera.setProjectionMatrixWithCulling(
          makePerspectiveMatrix(fovY, 1.0, 0.05, 10000), 0.05, 10000);

      await testHelper.capture(viewer.view,
          "camera_set_perspective_projection_culling_matrix_object_fov90");

      // cube no longer visible when the far plane is moved closer to camera so cube is outside
      fovY = 2 * (pi / 3);
      await camera.setProjectionMatrixWithCulling(
          makePerspectiveMatrix(fovY, 1.0, 0.05, 10000), 0.05, 10000);

      await testHelper.capture(viewer.view,
          "camera_set_perspective_projection_culling_matrix_object_fov120");
    });
  });

  // test('set custom projection/culling matrix (orthographic)', () async {
  //   await testHelper.withViewer((viewer) async {
  //     var camera = await viewer.getMainCamera();
  //     final cube = await viewer.createGeometry(GeometryHelper.cube());

  //     // cube is visible when inside the frustum, cube is visible
  //     var projectionMatrix =
  //         makeOrthographicMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 10000);
  //     await camera.setProjectionMatrixWithCulling(
  //         projectionMatrix, 0.05, 10000);

  //     await testHelper.capture(
  //         viewer, "camera_projection_culling_matrix_object_in_frustum");

  //     // cube no longer visible when the far plane is moved closer to camera so cube is outside
  //     projectionMatrix =
  //         makeOrthographicMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 1);
  //     await camera.setProjectionMatrixWithCulling(projectionMatrix, 0.05, 1);
  //     await testHelper.capture(
  //         viewer, "camera_projection_culling_matrix_object_outside_frustum");
  //   });
  // });

  test('setting transform on camera updates model matrix', () async {
    await testHelper.withViewer((viewer) async {
      var camera = await viewer.getActiveCamera();
      
      // explicitly set the model matrix first so we can check that the
      // transform is actually applied to the model matrix
      await camera.setModelMatrix(Matrix4.translation(Vector3.all(3)));
      
      await camera.setTransform(Matrix4.translation(Vector3.all(1)));

      var modelMatrix = await camera.getModelMatrix();
      expect(modelMatrix.getColumn(3).x, 1.0);
      expect(modelMatrix.getColumn(3).y, 1.0);
      expect(modelMatrix.getColumn(3).z, 1.0);
      expect(modelMatrix.getColumn(3).w, 1.0);
    });
  });

  // test('setting transform on camera updates model matrix (with parent)',
  //     () async {
  //   await testHelper.withViewer((viewer) async {
  //     var cameraEntity = await viewer.getMainCameraEntity();
  //     var camera = await viewer.getMainCamera();

  //     var parent = await viewer.createGeometry(GeometryHelper.cube());

  //     await viewer.setParent(camera.getEntity(), parent.entity);
  //     await viewer.setTransform(
  //         cameraEntity, Matrix4.translation(Vector3(1, 0, 0)));

  //     var modelMatrix = await camera.getModelMatrix();
  //     expect(modelMatrix.getColumn(3).x, 1.0);
  //     expect(modelMatrix.getColumn(3).y, 0.0);
  //     expect(modelMatrix.getColumn(3).z, 0.0);
  //     expect(modelMatrix.getColumn(3).w, 1.0);

  //     await viewer.setTransform(
  //         parent.entity, Matrix4.translation(Vector3(0, 1, 0)));
  //     modelMatrix = await camera.getModelMatrix();
  //     expect(modelMatrix.getColumn(3).x, 1.0);
  //     expect(modelMatrix.getColumn(3).y, 1.0);
  //     expect(modelMatrix.getColumn(3).z, 0.0);
  //     expect(modelMatrix.getColumn(3).w, 1.0);
  //   });
  // });

  // test(
  //     'when a camera is the parent of another entity, setting the model matrix updates the parent transform ',
  //     () async {
  //   await testHelper.withViewer((viewer) async {
  //     var camera = await viewer.createCamera();

  //     var child = await viewer
  //         .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
  //     await viewer.setParent(child.entity, camera.getEntity());

  //     await testHelper.capture(viewer, "camera_as_parent1");

  //     await camera.setModelMatrix(Matrix4.translation(Vector3(1, 0, 0)));

  //     await testHelper.capture(viewer, "camera_as_parent2");
  //   }, bg: kRed, cameraPosition: Vector3(0, 0, 10));
  // });

  // test('create camera', () async {
  //   await testHelper.withViewer((viewer) async {
  //     await viewer.setCameraPosition(0, 0, 5);
  //     await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);
  //     await viewer
  //         .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
  //     await testHelper.capture(viewer, "create_camera_main_camera");

  //     expect(viewer.getCameraCount(), 1);
  //     var newCamera = await viewer.createCamera();
  //     expect(viewer.getCameraCount(), 2);
  //     await newCamera.setTransform(Matrix4.translation(Vector3(0, 0, 4)));
  //     newCamera.setLensProjection();
  //     await viewer.setActiveCamera(newCamera);

  //     expect(await viewer.getActiveCamera(), newCamera);

  //     await testHelper.capture(viewer, "create_camera_new_camera");

  //     final mainCamera = await viewer.getMainCamera();
  //     await viewer.setActiveCamera(mainCamera);
  //     expect(await viewer.getActiveCamera(), mainCamera);
  //     await testHelper.capture(viewer, "create_camera_back_to_main");

  //     expect(viewer.getCameraCount(), 2);
  //     expect(viewer.getCameraAt(0), await viewer.getMainCamera());
  //     expect(viewer.getCameraAt(1), newCamera);
  //     await expectLater(
  //         () => viewer.getCameraAt(2), throwsA(isA<Exception>()));
  //   });
  // });
}
