import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';

import 'helpers.dart';

/// Returns the RGBA float at (x, y) of a captured float pixel buffer.
List<double> pixelAt(Float32List buffer, int width, int height, int x, int y) {
  final offset = (y * width + x) * 4;
  return [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]];
}

void main() async {
  final testHelper = TestHelper("material_reload");

  await testHelper.setup();

  final solidColorBytes = await loadResourceBytes("${testHelper.assetsDir}/solidcolor.filamat");

  test('findRenderablesUsingMaterial returns attached primitives', () async {
    await testHelper.withViewer((viewer) async {
      final material = await FilamentApp.instance!.createMaterial(solidColorBytes);
      final instance = await material.createInstance();
      await instance.setParameterFloat4("color", 0.0, 0.0, 1.0, 1.0);
      final cube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [instance],
      );

      final uses = await FilamentApp.instance!.findRenderablesUsingMaterial(material);
      expect(uses.length, 1, reason: "exactly one primitive uses the material");
      expect(uses.single.entity, cube.entity);
      expect(uses.single.primitiveIndex, 0);
      expect(
        uses.single.materialInstance,
        same(instance),
        reason: "looked-up instances must reuse the wrapper that recorded their state",
      );

      await viewer.destroyAsset(cube);
    }, bg: kWhite);
  });

  test('reloadMaterialFromBytes re-points renderables and replays parameters', () async {
    await testHelper.withViewer((viewer) async {
      final material = await FilamentApp.instance!.createMaterial(solidColorBytes);
      final instance = await material.createInstance();
      await instance.setParameterFloat4("color", 0.0, 0.0, 1.0, 1.0);
      final cube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [instance],
      );

      const width = 512;
      const height = 512;
      final beforePixels = (await testHelper.capture(viewer.view, "reload_before"))[viewer.view]!;
      final beforeCenter = pixelAt(beforePixels.buffer.asFloat32List(), width, height, width ~/ 2, height ~/ 2);
      expect(beforeCenter[2], greaterThan(0.4), reason: "cube renders blue before reload");
      expect(beforeCenter[0], lessThan(0.1));

      final reloaded = await FilamentApp.instance!.reloadMaterialFromBytes(material, solidColorBytes);
      expect(reloaded, isNot(same(material)));

      // The renderable now uses an instance of the NEW material.
      final usesAfter = await FilamentApp.instance!.findRenderablesUsingMaterial(reloaded);
      expect(usesAfter.length, 1);
      expect(usesAfter.single.entity, cube.entity);
      final newInstance = usesAfter.single.materialInstance as FFIMaterialInstance;
      expect(
        MaterialInstance_getMaterial(newInstance.pointer).address,
        (reloaded as FFIMaterial).pointer.address,
        reason: "attached instance must belong to the replacement material",
      );

      // The recorded parameter was replayed onto the replacement instance.
      expect(newInstance.shadow.parameters["color"], equals([0.0, 0.0, 1.0, 1.0]));

      // Rendering is unchanged by the swap.
      final afterPixels = (await testHelper.capture(viewer.view, "reload_after"))[viewer.view]!;
      final afterCenter = pixelAt(afterPixels.buffer.asFloat32List(), width, height, width ~/ 2, height ~/ 2);
      expect(afterCenter[2], greaterThan(0.4), reason: "cube still renders blue after reload");
      expect(afterCenter[0], lessThan(0.1));

      // And the replacement instance is live: mutating it changes the image.
      await newInstance.setParameterFloat4("color", 1.0, 0.0, 0.0, 1.0);
      final redPixels = (await testHelper.capture(viewer.view, "reload_red"))[viewer.view]!;
      final redCenter = pixelAt(redPixels.buffer.asFloat32List(), width, height, width ~/ 2, height ~/ 2);
      expect(redCenter[0], greaterThan(0.4), reason: "mutating the replacement instance recolors the cube");
      expect(redCenter[2], lessThan(0.1));

      await viewer.destroyAsset(cube);
    }, bg: kWhite);
  });

  test('reloadMaterialFromBytes preserves instance sharing', () async {
    await testHelper.withViewer((viewer) async {
      final material = await FilamentApp.instance!.createMaterial(solidColorBytes);
      final shared = await material.createInstance();
      await shared.setParameterFloat4("color", 0.0, 1.0, 0.0, 1.0);
      final cubeA = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [shared],
      );
      final cubeB = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [shared],
      );
      await cubeA.setTransform(Matrix4.translation(Vector3(-1.6, 0.0, 0.0)));
      await cubeB.setTransform(Matrix4.translation(Vector3(1.6, 0.0, 0.0)));

      final reloaded = await FilamentApp.instance!.reloadMaterialFromBytes(material, solidColorBytes);
      final usesAfter = await FilamentApp.instance!.findRenderablesUsingMaterial(reloaded);
      expect(usesAfter.length, 2, reason: "both cubes moved to the new material");
      expect(
        usesAfter[0].materialInstance,
        same(usesAfter[1].materialInstance),
        reason: "renderables that shared one instance must share one replacement",
      );
      expect(usesAfter.map((u) => u.entity).toSet(), {cubeA.entity, cubeB.entity});

      await viewer.destroyAsset(cubeA);
      await viewer.destroyAsset(cubeB);
    }, bg: kWhite);
  });

  test('reloadMaterialFromBytes with destroyOld=false leaves the old material alive', () async {
    await testHelper.withViewer((viewer) async {
      final material = await FilamentApp.instance!.createMaterial(solidColorBytes);
      final instance = await material.createInstance();
      await instance.setParameterFloat4("color", 0.0, 0.0, 1.0, 1.0);
      final cube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [instance],
      );

      final reloaded = await FilamentApp.instance!.reloadMaterialFromBytes(
        material,
        solidColorBytes,
        destroyOld: false,
      );
      expect(
        await (material as FFIMaterial).hasParameter("color"),
        isTrue,
        reason: "old material must still be alive when destroyOld is false",
      );

      // Caller owns both materials and every instance now. Order matters:
      // instances must not be destroyed while still attached to a renderable
      // (detach by destroying the asset first), and Filament requires
      // instances to be destroyed before their material.
      final liveUses = await FilamentApp.instance!.findRenderablesUsingMaterial(reloaded);
      await viewer.destroyAsset(cube);
      for (final use in liveUses) {
        await use.materialInstance.destroy();
      }
      await (reloaded as FFIMaterial).destroy();
      await instance.destroy();
      await material.destroy();
    }, bg: kWhite);
  });
}
