import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final h = TestHelper('sss_replacement');
  await h.setup();
  final app = FilamentApp.instance!;
  final results = <String, dynamic>{};
  Future<Float32List> capture(View view, String name) async {
    final bytes = (await h.capture(view, name)).values.single;
    return Float32List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
  }

  int changed(Float32List a, Float32List b, {double tolerance = 1 / 255}) {
    var n = 0;
    for (var i = 0; i < a.length; i += 4) {
      if ([0, 1, 2].any((c) => (a[i + c] - b[i + c]).abs() > tolerance)) n++;
    }
    return n;
  }

  ViewerBuilder scene() => ViewerBuilder(
    h,
  ).setViewportDimensions(256, 256).setCameraLookAt(Vector3(0, 0, 5), focus: Vector3.zero()).addSun();
  tearDownAll(() async {
    await File('${h.outDirPath}/audit.json').writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    print(const JsonEncoder.withIndent('  ').convert(results));
  });

  for (final pp in [false, true]) {
    test('zero strength is identity with post-processing $pp', () async {
      await scene().setPostProcessing(pp).execute((r) async {
        final asset = await r.viewer.loadGltf('${h.assetsDir}/cube.glb');
        final view = r.viewer.view;
        final before = await capture(view, 'identity_${pp}_off');
        final originalTarget = (await view.getRenderTarget())?.getNativeHandle();
        final viewsBefore = app.renderManager
            .getAttachedViews(app.renderManager.getAttachedSwapChains(view).single)
            .length;
        await view.setSubsurfaceScatteringEnabled(true);
        final sss = view.getSubsurfaceScattering()!;
        await sss.addSkin(asset);
        await sss.setParameters(const SubsurfaceScatteringParameters(intensity: 0));
        final after = await capture(view, 'identity_${pp}_zero');
        results['zero_strength_$pp'] = changed(before, after);
        expect(changed(before, after), 0);
        expect((await view.getRenderTarget())?.getNativeHandle(), originalTarget);
        expect(
          app.renderManager.getAttachedViews(app.renderManager.getAttachedSwapChains(view).single).length,
          viewsBefore,
        );
      });
    });
  }

  test('actual scene depth is available with post-processing off and on', () async {
    await scene().execute((r) async {
      await r.viewer.loadGltf('${h.assetsDir}/cube.glb');
      final view = r.viewer.view;
      await view.setSubsurfaceScatteringEnabled(true);
      for (final pp in [false, true]) {
        await view.setPostProcessing(pp);
        await view.getSubsurfaceScattering()!.setParameters(
          const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.depth),
        );
        final data = await capture(view, 'depth_$pp');
        final center = data[(128 * 256 + 128) * 4];
        results['depth_$pp'] = {'center': center, 'corner': data[0]};
        expect(center, greaterThan(0.00001));
        expect(center, greaterThan(data[0]));
      }
    });
  });

  test('guide matches asymmetric visible geometry exactly', () async {
    await scene().execute((r) async {
      final white = await app.createUbershaderMaterialInstance(unlit: true);
      await white.setParameterFloat4('baseColorFactor', 1, 1, 1, 1);
      final asset = await r.viewer.createGeometry(GeometryUtils.cube(), materialInstances: [white]);
      await asset.setTransform(
        Matrix4.compose(Vector3(0.5, 0.4, 0), Quaternion.axisAngle(Vector3(0, 0, 1), 0.35), Vector3(0.7, 0.4, 0.5)),
      );
      final before = await capture(r.viewer.view, 'coverage_reference');
      final lit = await app.createUbershaderMaterialInstance();
      for (final e in [asset.entity, ...await asset.getChildEntities()]) {
        if (app.renderableManager.hasComponent(e)) await app.renderableManager.setMaterialInstanceAt(e, 0, lit);
      }
      await r.viewer.view.setSubsurfaceScatteringEnabled(true);
      final sss = r.viewer.view.getSubsurfaceScattering()!;
      await sss.addSkin(asset);
      await sss.setParameters(
        const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.coverage),
      );
      final mask = await capture(r.viewer.view, 'coverage_guide');
      var mismatch = 0, covered = 0;
      for (var i = 0; i < mask.length; i += 4) {
        if (before[i] > 0.5) covered++;
        if ((before[i] > 0.5) != (mask[i] > 0.5)) mismatch++;
      }
      results['coverage'] = {'covered': covered, 'mismatch': mismatch};
      expect(covered, greaterThan(100));
      expect(mismatch, 0);
    });
  });

  test('hidden skin cannot change opaque foreground', () async {
    await scene().execute((r) async {
      final skin = await r.viewer.createGeometry(
        GeometryUtils.sphere(),
        materialInstances: [await app.createUbershaderMaterialInstance()],
      );
      await skin.setTransform(Matrix4.diagonal3Values(0.5, 0.5, 0.5));
      final material = await app.createUbershaderMaterialInstance(unlit: true);
      await material.setParameterFloat4('baseColorFactor', 0.8, 0.2, 0.1, 1);
      final fg = await r.viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
      await fg.setTransform(Matrix4.compose(Vector3(0, 0, 2), Quaternion.identity(), Vector3(1.5, 1.5, 0.1)));
      final before = await capture(r.viewer.view, 'occluded_off');
      await r.viewer.view.setSubsurfaceScatteringEnabled(true);
      final sss = r.viewer.view.getSubsurfaceScattering()!;
      await sss.addSkin(skin);
      await sss.setParameters(const SubsurfaceScatteringParameters(metersPerUnit: 0.01));
      final after = await capture(r.viewer.view, 'occluded_on');
      results['occluded_changed'] = changed(before, after);
      expect(changed(before, after), 0);
      await sss.setParameters(
        const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.coverage),
      );
      final coverage = await capture(r.viewer.view, 'occluded_coverage');
      expect(coverage.where((v) => v > 0.5).length, 256 * 256); // alpha only
    });
  });

  test('specular-only material is unchanged at full scattering strength', () async {
    await scene().execute((r) async {
      final material = await app.createUbershaderMaterialInstance();
      await material.setParameterFloat4('baseColorFactor', 0.8, 0.8, 0.8, 1);
      await material.setParameterFloat('metallicFactor', 1);
      await material.setParameterFloat('roughnessFactor', 0.25);
      final sphere = await r.viewer.createGeometry(GeometryUtils.sphere(), materialInstances: [material]);
      final view = r.viewer.view;
      final before = await capture(view, 'specular_off');
      await view.setSubsurfaceScatteringEnabled(true);
      final sss = view.getSubsurfaceScattering()!;
      await sss.addSkin(sphere);
      await sss.setParameters(const SubsurfaceScatteringParameters(metersPerUnit: 0.01));
      final after = await capture(view, 'specular_on');
      results['specular_changed'] = changed(before, after);
      expect(changed(before, after), 0);
      expect(before.where((v) => v > 0.1 && v < 0.99).length, greaterThan(10));
    });
  });

  test('diffuse scattering changes shading and preserves the silhouette', () async {
    await scene().execute((r) async {
      final material = await app.createUbershaderMaterialInstance();
      await material.setParameterFloat4('baseColorFactor', 0.8, 0.4, 0.25, 1);
      await material.setParameterFloat('metallicFactor', 0);
      final sphere = await r.viewer.createGeometry(GeometryUtils.sphere(), materialInstances: [material]);
      final view = r.viewer.view;
      final before = await capture(view, 'diffuse_off');
      await view.setSubsurfaceScatteringEnabled(true);
      final sss = view.getSubsurfaceScattering()!;
      await sss.addSkin(sphere);
      await sss.setParameters(const SubsurfaceScatteringParameters(metersPerUnit: 0.002));
      final after = await capture(view, 'diffuse_on');
      results['diffuse_changed'] = changed(before, after);
      expect(changed(before, after), greaterThan(10));
      await sss.setParameters(
        const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.coverage),
      );
      final coverage = await capture(view, 'diffuse_coverage');
      var outsideChanged = 0;
      for (var i = 0; i < before.length; i += 4) {
        if (coverage[i] < 0.5 && [0, 1, 2].any((c) => (before[i + c] - after[i + c]).abs() > 1 / 255)) outsideChanged++;
      }
      results['outside_changed'] = outsideChanged;
      expect(outsideChanged, 0);
      await view.setSubsurfaceScatteringEnabled(false);
      final restored = await capture(view, 'diffuse_restored');
      expect(changed(before, restored), 0);
    });
  });
  test('coverage follows morph and skeletal deformation in the actual color pass', () async {
    await ViewerBuilder(
      h,
    ).setViewportDimensions(256, 256).setCameraLookAt(Vector3(3, 2, 6), focus: Vector3.zero()).execute((r) async {
      final asset = await r.viewer.loadGltf('${h.assetsDir}/cube_with_morph_targets.glb');
      final morph = (await asset.getMorphTargetSets()).single;
      final view = r.viewer.view;
      await view.setSubsurfaceScatteringEnabled(true);
      final sss = view.getSubsurfaceScattering()!;
      await sss.addSkin(asset);
      Float32List? rest;
      for (final pose in ['rest', 'morph', 'bone']) {
        await morph.setAllWeights([pose == 'morph' ? 1 : 0]);
        await app.renderableManager.setBonesFromMat4(morph.entity, [
          pose == 'bone' ? Matrix4.rotationY(0.7) : Matrix4.identity(),
        ]);
        await sss.setParameters(
          const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.coverage),
        );
        final mask = await capture(view, 'animation_${pose}_coverage');
        await sss.setParameters(
          const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.depth),
        );
        final depth = await capture(view, 'animation_${pose}_depth');
        var mismatches = 0, covered = 0;
        for (var i = 0; i < mask.length; i += 4) {
          if (mask[i] > 0.5) covered++;
          if ((mask[i] > 0.5) != (depth[i] > 0)) mismatches++;
        }
        results['animation_$pose'] = {'covered': covered, 'mismatches': mismatches};
        expect(covered, greaterThan(100));
        expect(mismatches, 0);
        if (rest != null) expect(changed(rest, mask), greaterThan(100));
        rest ??= mask;
      }
    });
  });

  for (final emission in [false, true]) {
    test('${emission ? 'emission' : 'indirect specular'} bypasses scattering', () async {
      await ViewerBuilder(
        h,
      ).setViewportDimensions(256, 256).setCameraLookAt(Vector3(0, 0, 5), focus: Vector3.zero()).execute((r) async {
        if (!emission) await r.viewer.loadIbl('file://${h.assetsDir}/default_env_ibl.ktx');
        final mat = await app.createUbershaderMaterialInstance();
        await mat.setParameterFloat4('baseColorFactor', emission ? 0 : 0.8, emission ? 0 : 0.8, emission ? 0 : 0.8, 1);
        await mat.setParameterFloat('metallicFactor', 1);
        await mat.setParameterFloat('roughnessFactor', 0.15);
        if (emission) {
          await mat.setParameterFloat('emissiveStrength', 1);
          await mat.setParameterFloat3('emissiveFactor', 0.3, 0.5, 0.8);
        }
        final sphere = await r.viewer.createGeometry(GeometryUtils.sphere(), materialInstances: [mat]);
        final before = await capture(r.viewer.view, 'bypass_${emission}_off');
        await r.viewer.view.setSubsurfaceScatteringEnabled(true);
        final sss = r.viewer.view.getSubsurfaceScattering()!;
        await sss.addSkin(sphere);
        await sss.setParameters(const SubsurfaceScatteringParameters(metersPerUnit: 0.002));
        final after = await capture(r.viewer.view, 'bypass_${emission}_on');
        results[emission ? 'emission_changed' : 'indirect_specular_changed'] = changed(before, after);
        expect(changed(before, after), 0);
        expect(before.where((v) => v > 0.1 && v < 0.99).length, greaterThan(10));
      });
    });
  }
  test('indirect diffuse lighting preserves black and colored albedo', () async {
    await ViewerBuilder(
      h,
    ).setViewportDimensions(128, 128).setCameraLookAt(Vector3(0, 0, 4), focus: Vector3.zero()).execute((r) async {
      final camera = await r.viewer.getActiveCamera();
      await camera.setProjection(Projection.Orthographic, -4, 4, -4, 4, 0.1, 100);
      await r.viewer.view.setAntiAliasing(false, false, false);
      await r.viewer.loadIbl('file://${h.assetsDir}/default_env_ibl.ktx');
      final halves = <ThermionAsset>[];
      for (final side in [-1, 1]) {
        final m = await app.createUbershaderMaterialInstance();
        await m.setParameterFloat4('baseColorFactor', side < 0 ? 0 : 0.5, side < 0 ? 0.5 : 0, 0.25, 1);
        await m.setParameterFloat('metallicFactor', 0);
        await m.setParameterFloat('reflectance', 0);
        final half = await r.viewer.createGeometry(GeometryUtils.cube(), materialInstances: [m]);
        await half.setTransform(Matrix4.compose(Vector3(side * 8, 0, -5), Quaternion.identity(), Vector3(8, 16, 5)));
        halves.add(half);
      }
      final before = await capture(r.viewer.view, 'ibl_texture_off');
      await r.viewer.view.setSubsurfaceScatteringEnabled(true);
      final sss = r.viewer.view.getSubsurfaceScattering()!;
      for (final half in halves) {
        await sss.addPrimitive(half.entity, 0, transportGroup: 91);
      }
      await sss.setParameters(
        const SubsurfaceScatteringParameters(
          diffusionDistanceRedMm: 12.5,
          diffusionDistanceGreenMm: 6.25,
          diffusionDistanceBlueMm: 3.125,
          metersPerUnit: 0.1,
        ),
      );
      final after = await capture(r.viewer.view, 'ibl_texture_on');
      results['ibl_texture_changed'] = changed(before, after);
      expect(changed(before, after), 0);
      expect(before[(64 * 128 + 40) * 4 + 1], greaterThan(0.05));
      expect(before[(64 * 128 + 90) * 4], greaterThan(0.05));
    });
  });

  for (final ortho in [false, true]) {
    test('physical profile is invariant under scene-unit scaling (ortho=$ortho)', () async {
      await scene().execute((r) async {
        final camera = await r.viewer.getActiveCamera();
        final mat = await app.createUbershaderMaterialInstance();
        await mat.setParameterFloat4('baseColorFactor', 0.8, 0.4, 0.25, 1);
        await mat.setParameterFloat('metallicFactor', 0);
        final sphere = await r.viewer.createGeometry(GeometryUtils.sphere(), materialInstances: [mat]);
        await r.viewer.view.setSubsurfaceScatteringEnabled(true);
        final sss = r.viewer.view.getSubsurfaceScattering()!;
        await sss.addSkin(sphere);
        Float32List? original;
        for (final scale in [1.0, 10.0]) {
          await sphere.setTransform(Matrix4.diagonal3Values(scale, scale, scale));
          await camera.lookAt(Vector3(0, 0, 5 * scale), focus: Vector3.zero());
          if (ortho) {
            await camera.setProjection(
              Projection.Orthographic,
              -2 * scale,
              2 * scale,
              -2 * scale,
              2 * scale,
              0.1 * scale,
              100 * scale,
            );
          } else {
            await camera.setProjectionFromVerticalFieldOfView(45, 0.1 * scale, 100 * scale, 1);
          }
          await sss.setParameters(SubsurfaceScatteringParameters(metersPerUnit: 0.002 / scale));
          final data = await capture(r.viewer.view, 'units_${ortho}_$scale');
          if (original != null) {
            results['unit_scale_$ortho'] = changed(original, data);
            expect(changed(original, data), 0);
          }
          original = data;
        }
      });
    });
  }
  // Independent material and illumination fixtures. A texture edge must remain
  // sharp; a shadow edge on uniform albedo must spread according to the profile.
  for (final ortho in [false, true]) {
    for (final shadow in [false, true]) {
      test('${shadow ? 'shadow diffusion' : 'albedo preservation'} (ortho=$ortho)', () async {
        const size = 128;
        await ViewerBuilder(h)
            .setViewportDimensions(size, size)
            .setPostProcessing(false)
            .setShadowsEnabled(shadow)
            .setShadowType(ShadowType.PCF)
            .setCameraLookAt(Vector3(0, 0, 4), focus: Vector3.zero())
            .addSun(
              color: LinearColor(1, 1, 1),
              colorTemperature: null,
              direction: Vector3(shadow ? 1 : 0, 0, -1).normalized(),
            )
            .execute((r) async {
              final camera = await r.viewer.getActiveCamera();
              final view = r.viewer.view;
              await view.setAntiAliasing(false, false, false);
              if (shadow) {
                await app.lightManager.setShadowOptions(r.sun!, ShadowOptions(mapSize: 2048, lispsm: false));
              }
              final halves = <ThermionAsset>[];
              for (final side in [-1, 1]) {
                final material = await app.createUbershaderMaterialInstance();
                final v = !shadow && side < 0 ? 0.0 : 0.5;
                await material.setParameterFloat4('baseColorFactor', v, v, v, 1);
                await material.setParameterFloat('metallicFactor', 0);
                await material.setParameterFloat('roughnessFactor', 0);
                await material.setParameterFloat('reflectance', 0);
                final half = await r.viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
                await half.setTransform(
                  Matrix4.compose(Vector3(side * 8, 0, -5), Quaternion.identity(), Vector3(8, 16, 5)),
                );
                halves.add(half);
                await half.setReceiveShadows(true);
                await half.setCastShadows(true);
              }
              if (shadow) {
                // Behind the camera but between the directional light and receiver.
                // The right edge at x=-10,z=10 casts a vertical shadow at x=0,z=0.
                final black = await app.createUbershaderMaterialInstance();
                await black.setParameterFloat4('baseColorFactor', 0, 0, 0, 1);
                await black.setCullingMode(CullingMode.NONE);
                final blocker = await r.viewer.createGeometry(GeometryUtils.cube(), materialInstances: [black]);
                await blocker.setCastShadows(true);
                await blocker.setTransform(
                  Matrix4.compose(Vector3(-42.01, 0, 10), Quaternion.identity(), Vector3(32, 32, 0.01)),
                );
              }
              await view.setSubsurfaceScatteringEnabled(true);
              final sss = view.getSubsurfaceScattering()!;
              Future<void> select(bool shared) async {
                for (final half in halves) await sss.removeSkin(half);
                for (var i = 0; i < halves.length; i++) {
                  final half = halves[i];
                  for (final e in [half.entity, ...await half.getChildEntities()]) {
                    if (app.renderableManager.hasComponent(e)) {
                      await sss.addPrimitive(e, 0, transportGroup: shared ? 73 : 74 + i);
                    }
                  }
                }
              }

              await select(true);

              // The marginal CDF follows from integrating the analytic radial
              // survival probability over angle. This is independent of the GPU's
              // Cartesian 3x3 quadrature, sampled depth, and inverse projection.
              double cdf(double x, double d) {
                if (x == 0) return 0.5;
                const steps = 1200;
                const retained = 0.9963790093708328;
                var tail = 0.0;
                for (var i = 0; i < steps; i++) {
                  final theta = (i + 0.5) * math.pi / (2 * steps);
                  final radius = x.abs() / math.cos(theta);
                  final survival = 0.25 * math.exp(-radius / d) + 0.75 * math.exp(-radius / (3 * d));
                  tail += math.max(0, (survival - (1 - retained)) / retained) / (2 * steps);
                }
                return x < 0 ? tail : 1 - tail;
              }

              for (final distance in [4.0, 8.0]) {
                await camera.lookAt(Vector3(0, 0, distance), focus: Vector3.zero());
                if (ortho) {
                  await camera.setProjection(Projection.Orthographic, -4, 4, -4, 4, 0.1, 100);
                } else {
                  await camera.setProjectionFromVerticalFieldOfView(90, 0.1, 100, 1);
                }
                await sss.setParameters(const SubsurfaceScatteringParameters(intensity: 0));
                final prefix = '${shadow ? 'shadow' : 'texture'}_${ortho}_$distance';
                final before = await capture(view, '${prefix}_off');
                final row = List<double>.generate(size, (x) => before[(64 * size + x) * 4]);
                final contrast = row[100] - row[28];
                expect(contrast, greaterThan(0.2), reason: 'The fixture must have a visible edge');
                results['${prefix}_off_row'] = row;
                for (final dMm in [6.25, 12.5]) {
                  await sss.setParameters(
                    SubsurfaceScatteringParameters(
                      diffusionDistanceRedMm: dMm,
                      diffusionDistanceGreenMm: dMm,
                      diffusionDistanceBlueMm: dMm,
                      metersPerUnit: 0.1,
                    ),
                  );
                  final data = await capture(view, '${prefix}_$dMm');
                  final dWorld = dMm * 0.001 / 0.1;
                  final dPixels = dWorld * (ortho ? size / 8 : size / (2 * distance));
                  final weights = List<double>.generate(
                    65,
                    (i) => cdf(i - 32 + 0.5, dPixels) - cdf(i - 32 - 0.5, dPixels),
                  );
                  var maxError = 0.0, maxChange = 0.0;
                  for (var x = 40; x < 88; x++) {
                    var expected = row[x];
                    if (shadow) {
                      for (var i = 0; i < 65; i++) {
                        expected += weights[i] * (row[x + i - 32] - row[x]);
                      }
                    }
                    final value = data[(64 * size + x) * 4];
                    maxError = math.max(maxError, (value - expected).abs() / contrast);
                    maxChange = math.max(maxChange, (value - row[x]).abs() / contrast);
                  }
                  results['${prefix}_$dMm'] = {
                    'diffusion_distance_pixels': dPixels,
                    'max_normalized_error': maxError,
                    'max_normalized_change': maxChange,
                    'row': List.generate(size, (x) => data[(64 * size + x) * 4]),
                  };
                  expect(maxError, lessThan(0.02), reason: '$prefix d=$dPixels px');
                  if (shadow) expect(maxChange, greaterThan(0.03));
                  if (shadow && distance == 4 && dMm == 12.5) {
                    await sss.setParameters(
                      const SubsurfaceScatteringParameters(
                        diffusionDistanceRedMm: 12.5,
                        diffusionDistanceGreenMm: 6.25,
                        diffusionDistanceBlueMm: 3.125,
                        metersPerUnit: 0.1,
                      ),
                    );
                    final rgb = await capture(view, '${prefix}_rgb');
                    final errors = <double>[];
                    for (var c = 0; c < 3; c++) {
                      final channelD = dPixels / math.pow(2, c);
                      final channelWeights = List.generate(
                        65,
                        (i) => cdf(i - 32 + 0.5, channelD) - cdf(i - 32 - 0.5, channelD),
                      );
                      var error = 0.0;
                      for (var x = 40; x < 88; x++) {
                        final center = before[(64 * size + x) * 4 + c];
                        var expected = center;
                        for (var i = 0; i < 65; i++) {
                          expected += channelWeights[i] * (before[(64 * size + x + i - 32) * 4 + c] - center);
                        }
                        error = math.max(error, (rgb[(64 * size + x) * 4 + c] - expected).abs() / contrast);
                      }
                      expect(error, lessThan(0.02));
                      errors.add(error);
                    }
                    results['${prefix}_rgb_error'] = errors;
                    await sss.setParameters(
                      const SubsurfaceScatteringParameters(
                        diffusionDistanceRedMm: 12.5,
                        diffusionDistanceGreenMm: 12.5,
                        diffusionDistanceBlueMm: 12.5,
                        metersPerUnit: 0.1,
                      ),
                    );
                    await select(false);
                    final separate = await capture(view, '${prefix}_separate_groups');
                    var difference = 0.0;
                    for (var x = 58; x < 70; x++) {
                      difference = math.max(
                        difference,
                        (separate[(64 * size + x) * 4] - data[(64 * size + x) * 4]).abs(),
                      );
                    }
                    results['${prefix}_group_difference'] = difference;
                    expect(
                      difference,
                      greaterThan(0.01),
                      reason: 'Separate groups must stop light crossing the material boundary',
                    );
                    await select(true);
                  }
                }
              }
            });
      });
    }
  }
}
