import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart' show TCompilerPriorityQueueExt;

import 'helpers.dart';

/// Renders one frame with [frame] (or just pumps the engine when null) until
/// [compile] completes, failing after [timeout]. Filament only delivers the
/// compile completion while the engine executes, so frames must keep coming.
Future<void> pumpUntil(
  Future<void> compile, {
  Future<void> Function()? frame,
  Duration timeout = const Duration(seconds: 60),
}) async {
  var done = false;
  compile.then((_) => done = true, onError: (Object _) => done = true);
  final app = FilamentApp.instance! as FFIFilamentApp;
  final deadline = DateTime.now().add(timeout);
  while (!done) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Material.compile did not complete within $timeout');
    }
    if (frame != null) {
      await frame();
    } else {
      await withVoidCallback((id, cb) => Engine_executeJobThread(app.jobThreadHandle, app.engine, id, cb));
      await app.flush();
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
  await compile;
}

void main() async {
  final testHelper = TestHelper("material_compile");
  await testHelper.setup();

  test('compile completes with an explicit priority and variant mask, material still usable', () async {
    final app = FilamentApp.instance!;
    final material = await app.createBuiltInMaterial(BuiltInMaterial.normalColor);
    addTearDown(material.destroy);

    // Warm the shaders without rendering anything.
    var completed = false;
    final compile = material
        .compile(
          priority: CompilerPriorityQueue.high,
          variants: {UserVariantFilterBit.directionalLighting, UserVariantFilterBit.dynamicLighting},
        )
        .then((_) => completed = true);
    expect(completed, isFalse);
    await pumpUntil(compile);

    // The compiled material still produces instances that accept parameters.
    final instance = await material.createInstance();
    addTearDown(instance.destroy);
    await instance.setParameterFloat('opacity', 1.0);
    expect(await instance.isStencilWriteEnabled(), isFalse);

    // A second compile of the same variants is already satisfied and still
    // reports completion; so is the default (every variant, low priority).
    await pumpUntil(material.compile());
    await pumpUntil(material.compile(variants: {UserVariantFilterBit.fog}));
  });

  test('a compiled material renders', () async {
    await ViewerBuilder(testHelper).setCameraPosition(Vector3(2, 2, 2)).execute((result) async {
      final asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb", addToScene: true);

      final material = await FilamentApp.instance!.createBuiltInMaterial(BuiltInMaterial.normalColor);
      addTearDown(material.destroy);

      // Compile while frames are in flight, then draw with the material.
      await pumpUntil(
        material.compile(priority: CompilerPriorityQueue.low, variants: {UserVariantFilterBit.directionalLighting}),
        frame: () async => testHelper.capture(result.viewer.view, null),
      );

      final instance = await material.createInstance();
      addTearDown(instance.destroy);
      await asset.setMaterialInstanceForAll(instance);
      final frame = (await testHelper.capture(result.viewer.view, "material_compile_normal_color")).values.single;
      final pixels = Float32List.fromList(frame.buffer.asFloat32List(frame.offsetInBytes, frame.lengthInBytes ~/ 4));
      var visiblePixels = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        if (pixels[i] > 0.45) visiblePixels++;
      }
      expect(visiblePixels, greaterThan(100));

      await result.viewer.removeFromScene(asset);
    });
  });

  test('variant mask helper mirrors the native bit values', () {
    expect(UserVariantFilterBit.maskOf(UserVariantFilterBit.all), TUserVariantFilterBit.USER_VARIANT_ALL);
    expect(
      UserVariantFilterBit.maskOf({UserVariantFilterBit.directionalLighting, UserVariantFilterBit.fog}),
      TUserVariantFilterBit.USER_VARIANT_DIRECTIONAL_LIGHTING | TUserVariantFilterBit.USER_VARIANT_FOG,
    );
    expect(CompilerPriorityQueue.critical.toFFI(), TCompilerPriorityQueue.COMPILER_PRIORITY_CRITICAL);
  });
}
