import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

Future<
    ({
      ThermionAsset blueCube,
      MaterialInstance blueMaterialInstance,
      ThermionAsset greenCube,
      MaterialInstance greenMaterialInstance
    })> setup(ThermionViewer viewer) async {
  var blueMaterialInstance =
      await FilamentApp.instance!.createUnlitMaterialInstance();
  final blueCube = await viewer.createGeometry(GeometryHelper.cube(),
      materialInstances: [blueMaterialInstance]);
  await blueMaterialInstance.setParameterFloat4(
      "baseColorFactor", 0.0, 0.0, 1.0, 1.0);

  // Position blue cube slightly behind/below/right
  await blueCube.setTransform(Matrix4.translation(Vector3(1.0, -1.0, -1.0)));

  var greenMaterialInstance =
      await FilamentApp.instance!.createUnlitMaterialInstance();
  final greenCube = await viewer.createGeometry(GeometryHelper.cube(),
      materialInstances: [greenMaterialInstance]);
  await greenMaterialInstance.setParameterFloat4(
      "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

  return (
    blueCube: blueCube,
    blueMaterialInstance: blueMaterialInstance,
    greenCube: greenCube,
    greenMaterialInstance: greenMaterialInstance
  );
}

void main() async {
  final testHelper = TestHelper("material");

  await testHelper.setup();

  test('disable depth write', () async {
    await testHelper.withViewer((viewer) async {
      final (
        :blueCube,
        :blueMaterialInstance,
        :greenCube,
        :greenMaterialInstance
      ) = await setup(viewer);

      // With depth write enabled on both materials, green cube renders behind the blue cube
      await testHelper.capture(
          viewer.view, "material_instance_depth_write_enabled");

      // Disable depth write on green cube
      // Blue cube will always appear in front
      await greenMaterialInstance.setDepthWriteEnabled(false);
      await testHelper.capture(
          viewer.view, "material_instance_depth_write_disabled");

      // Set priority for greenCube to render last, making it appear in front
      await viewer.setPriority(greenCube.entity, 7);
      await testHelper.capture(
          viewer.view, "material_instance_depth_write_disabled_with_priority");
    });
  });
  
  test('set depth func to NEVER', () async {
    await testHelper.withViewer((viewer) async {
      final (
        :blueCube,
        :blueMaterialInstance,
        :greenCube,
        :greenMaterialInstance
      ) = await setup(viewer);

      // Set depth func to NEVER on green cube
      await greenMaterialInstance.setDepthFunc(SamplerCompareFunction.N);
      // Green cube is not rendered at all
      await testHelper.capture(viewer.view, "depth_func_never");
    });
  });
}
