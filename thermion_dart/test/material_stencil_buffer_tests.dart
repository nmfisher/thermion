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
  final testHelper = TestHelper("stencil");

  await testHelper.setup();

  test('enable stencil write', () async {
    await testHelper.withViewer((viewer) async {
      final (
        :blueCube,
        :blueMaterialInstance,
        :greenCube,
        :greenMaterialInstance
      ) = await setup(viewer);

      // force depth to always pass so we're just comparing stencil test
      await greenMaterialInstance.setDepthFunc(SamplerCompareFunction.A);
      await blueMaterialInstance.setDepthFunc(SamplerCompareFunction.A);

      await testHelper.capture(
          viewer.view, "material_instance_depth_pass_stencil_disabled");

      assert(await greenMaterialInstance.isStencilWriteEnabled() == false);
      assert(await blueMaterialInstance.isStencilWriteEnabled() == false);

      await greenMaterialInstance.setStencilWriteEnabled(true);
      await blueMaterialInstance.setStencilWriteEnabled(true);

      assert(await greenMaterialInstance.isStencilWriteEnabled() == true);
      assert(await blueMaterialInstance.isStencilWriteEnabled() == true);

      await viewer.view.setStencilBufferEnabled(true);
      assert(await viewer.view.isStencilBufferEnabled(), true);

      // just a sanity check, output should be the same as above
      await testHelper.capture(
          viewer.view, "material_instance_depth_pass_stencil_enabled");
    }, postProcessing: true, bg: null, createStencilBuffer: true);
  });

  test('set stencil compare function to never/always/lt/gt)', () async {
    await testHelper.withViewer((viewer) async {
      final (
        :blueCube,
        :blueMaterialInstance,
        :greenCube,
        :greenMaterialInstance
      ) = await setup(viewer);

      await viewer.view.setStencilBufferEnabled(true);

      // ensure the blue cube renders before the green cube
      await viewer.setPriority(greenCube.entity, 7);
      await viewer.setPriority(blueCube.entity, 0);

      for (final mi in [greenMaterialInstance, blueMaterialInstance]) {
        await mi.setStencilWriteEnabled(true);
        await mi.setDepthCullingEnabled(false);
      }

      // set stencil compare function to NEVER
      for (final mi in [greenMaterialInstance, blueMaterialInstance]) {
        await mi.setStencilCompareFunction(
            SamplerCompareFunction.N, StencilFace.FRONT_AND_BACK);
      }
      
      // should be totally empty
      await testHelper.capture(viewer.view, "stencil_never");

      // set stencil compare function to ALWAYS
      for (final mi in [greenMaterialInstance, blueMaterialInstance]) {
        await mi.setStencilCompareFunction(
            SamplerCompareFunction.A, StencilFace.FRONT_AND_BACK);
      }

      // should show green cube in front of blue cube
      await testHelper.capture(viewer.view, "stencil_always");

      // set the blue cube to always pass the stencil test
      await blueMaterialInstance.setStencilCompareFunction(
            SamplerCompareFunction.A, StencilFace.FRONT_AND_BACK);
      // when blue cube passes depth + stencil, replace the default stencil value (0) with 1
      await blueMaterialInstance.setStencilOpDepthStencilPass(StencilOperation.REPLACE);
      await blueMaterialInstance.setStencilReferenceValue(1);
      
      // set the green cube to only pass the stencil test where stencil value is 
      // not equal to 0
      await greenMaterialInstance.setStencilCompareFunction(
            SamplerCompareFunction.NE, StencilFace.FRONT_AND_BACK);      
      await greenMaterialInstance.setStencilReferenceValue(0);

      // green cube will only be rendered where it overlaps with blue cube 
      await testHelper.capture(viewer.view, "stencil_ne");

      // set the green cube to only pass the stencil test where stencil value is 
      // equal to 0
      await greenMaterialInstance.setStencilCompareFunction(
            SamplerCompareFunction.E, StencilFace.FRONT_AND_BACK);      
      
      // green cube renders where it does not overlap with blue cube (same as if 
      // we had disabled depth writes and rendered the green cube, then the blue 
      // cube)
      await testHelper.capture(viewer.view, "stencil_eq");

    },
        bg: null,
        postProcessing: true,
        createStencilBuffer: true,
        createRenderTarget: false);
  });

  // test('fail stencil not equal', () async {
  //   await testHelper.withViewer((viewer) async {
  //     final (
  //       :blueCube,
  //       :blueMaterialInstance,
  //       :greenCube,
  //       :greenMaterialInstance
  //     ) = await setup(viewer);

  //     // this ensures the blue cube is rendered before the green cube
  //     await viewer.setPriority(blueCube.entity, 0);
  //     await viewer.setPriority(greenCube.entity, 1);

  //     await blueMaterialInstance.setStencilWriteEnabled(true);
  //     await blueMaterialInstance.setStencilReferenceValue(1);
  //     await blueMaterialInstance
  //         .setStencilCompareFunction(SamplerCompareFunction.A);
  //     await blueMaterialInstance
  //         .setStencilOpDepthStencilPass(StencilOperation.REPLACE);

  //     await greenMaterialInstance.setStencilReferenceValue(1);
  //     await greenMaterialInstance
  //         .setStencilCompareFunction(SamplerCompareFunction.E);

  //     // green cube is only rendered where it intersects with the blue cube
  //     await testHelper.capture(viewer.view, "fail_stencil_ne");
  //   }, postProcessing: true);
  // });
}
