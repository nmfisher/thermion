import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'src/test_io.dart';

/// Runtime material compilation (filamat) is opt-in via the
/// `runtime_materials` user define; the CI workflow runs this file in a leg
/// that appends `runtime_materials: true` to the consuming package's
/// pubspec.yaml before building. In the default leg the test asserts the
/// feature is reported unsupported and the API throws UnsupportedError.
Future<void> main() => runRuntimeMaterialTests();

Future<void> runRuntimeMaterialTests({bool? expectedSupport}) async {
  await initTestBindings();
  await FFIFilamentApp.create(
    config: FFIFilamentConfig(loadResource: loadResourceBytes, backend: defaultTestBackend),
  );

  final app = FilamentApp.instance!;
  tearDownAll(app.destroy);

  const source = '''
void material(inout MaterialInputs material) {
  prepareMaterial(material);
  material.baseColor.rgb = float3(1.0, 0.0, 0.0);
  material.roughness = 0.5;
  material.metallic = 0.0;
}
''';

  test('runtimeMaterialsSupported matches the requested build', () async {
    if (expectedSupport == null) {
      expect(app.runtimeMaterialsSupported, isA<bool>());
    } else {
      expect(app.runtimeMaterialsSupported, expectedSupport);
    }
  });

  test('compileMaterialSource compiles, validates, and instantiates', () async {
    if (!app.runtimeMaterialsSupported) {
      // Default build (no runtime_materials flag): must throw, not crash.
      expect(() => app.compileMaterialSource('runtime_test', source), throwsUnsupportedError);
      return;
    }
    final material = await app.compileMaterialSource('runtime_test', source, shading: MaterialShading.lit);
    addTearDown(material.destroy);

    // createMaterial already verified the package version while building
    // (Material_getPackageVersion == Material_getSupportedVersion), so
    // reaching here proves the filamat-produced package is loadable.
    expect(await material.hasParameter('baseColorIndex'), isFalse);

    final instance = await material.createInstance();
    addTearDown(instance.destroy);
    await instance.setDepthWriteEnabled(true);
  });

  test('empty source is rejected before any native work', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialSource('runtime_test', ''), throwsUnsupportedError);
      return;
    }
    expect(() => app.compileMaterialSource('runtime_test', ''), throwsArgumentError);
  });

  // Full .mat package source (material config block + fragment block), the
  // format matc accepts. Validated against matc from the pinned Filament
  // release, including the #include resolution against the map below.
  const packageSource = '''
material {
    name : "RuntimePackageTest",
    shadingModel : unlit,
    parameters : [
        { type : float4, name : baseColor }
    ]
}

fragment {
    #include "common.glsl"
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor.rgb = tintBaseColor(materialParams.baseColor.rgb);
        material.baseColor.a = materialParams.baseColor.a;
    }
}
''';

  const packageIncludes = {
    'common.glsl': '''
// Shared helper resolved from the includes map.
vec3 tintBaseColor(vec3 color) {
    return color * vec3(1.0, 0.9, 0.8);
}
''',
  };

  test('compileMaterialPackage compiles a .mat with parameters and includes', () async {
    if (!app.runtimeMaterialsSupported) {
      // Default build (no runtime_materials flag): must throw, not crash.
      expect(
        () => app.compileMaterialPackage('runtime_package_test', packageSource, includes: packageIncludes),
        throwsUnsupportedError,
      );
      return;
    }
    final material = await app.compileMaterialPackage('runtime_package_test', packageSource, includes: packageIncludes);
    addTearDown(material.destroy);

    // The parameter block survived parsing and reflection.
    expect(await material.hasParameter('baseColor'), isTrue);
    expect(await material.hasParameter('notAParameter'), isFalse);

    final instance = await material.createInstance();
    addTearDown(instance.destroy);
    await instance.setParameterFloat4('baseColor', 1.0, 0.0, 0.0, 1.0);
    await instance.setDepthWriteEnabled(true);
  });

  test('compileMaterialPackage resolves nested includes from the same map', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialPackage('runtime_package_nested', packageSource), throwsUnsupportedError);
      return;
    }
    const nestedSource = '''
material {
    name : "RuntimePackageNested",
    shadingModel : unlit,
    parameters : [
        { type : float4, name : baseColor }
    ]
}

fragment {
    #include "outer.glsl"
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = outerTint(materialParams.baseColor);
    }
}
''';
    final material = await app.compileMaterialPackage(
      'runtime_package_nested',
      nestedSource,
      includes: {
        'outer.glsl': '''
#include "common.glsl"
vec4 outerTint(vec4 color) {
    return vec4(tintBaseColor(color.rgb), color.a);
}
''',
        ...packageIncludes,
      },
    );
    addTearDown(material.destroy);
    expect(await material.hasParameter('baseColor'), isTrue);
  });

  test('compileMaterialPackage works without includes', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialPackage('runtime_package_plain', packageSource), throwsUnsupportedError);
      return;
    }
    // Same source with the include inlined and no includes map at all.
    final inlineSource = packageSource.replaceFirst('#include "common.glsl"', packageIncludes['common.glsl']!);
    final material = await app.compileMaterialPackage('runtime_package_plain', inlineSource);
    addTearDown(material.destroy);
    expect(await material.hasParameter('baseColor'), isTrue);
  });

  test('compileMaterialPackage fails on an unresolvable include', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialPackage('runtime_package_missing', packageSource), throwsUnsupportedError);
      return;
    }
    // packageSource includes common.glsl, which is absent from the map.
    expect(
      () => app.compileMaterialPackage('runtime_package_missing', packageSource, includes: {'other.glsl': ''}),
      throwsStateError,
    );
  });

  test('compileMaterialPackage fails on malformed .mat source', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialPackage('runtime_package_malformed', 'not a material'), throwsUnsupportedError);
      return;
    }
    expect(() => app.compileMaterialPackage('runtime_package_malformed', 'this is not a .mat file'), throwsStateError);
  });

  test('compileMaterialPackage rejects empty source before any native work', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialPackage('runtime_package_test', ''), throwsUnsupportedError);
      return;
    }
    expect(() => app.compileMaterialPackage('runtime_package_test', ''), throwsArgumentError);
  });

  const customLitSource = '''
material {
    name : RuntimeCustomLighting,
    shadingModel : lit,
    customSurfaceShading : true,
    parameters : [ { type : float3, name : tint } ]
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor.rgb = materialParams.tint;
        material.roughness = 0.7;
    }
    vec3 surfaceShading(const MaterialInputs materialInputs,
            const ShadingData shadingData, const LightData lightData) {
        return shadingData.diffuseColor * lightData.colorIntensity.rgb
                * lightData.NdotL * lightData.visibility;
    }
}
''';

  test('compileMaterialPackage supports custom surface shading on lit materials', () async {
    if (!app.runtimeMaterialsSupported) {
      await expectLater(app.compileMaterialPackage('custom_lit', customLitSource), throwsUnsupportedError);
      return;
    }
    final material = await app.compileMaterialPackage('custom_lit', customLitSource);
    addTearDown(material.destroy);
    expect(await material.hasParameter('tint'), isTrue);
    final instance = await material.createInstance();
    addTearDown(instance.destroy);
    await instance.setParameterFloat3('tint', 0.5, 0.3, 0.1);
  });

  test('custom surface shading rejects non-lit materials', () async {
    final unlit = customLitSource.replaceFirst('shadingModel : lit', 'shadingModel : unlit');
    await expectLater(
      app.compileMaterialPackage('custom_unlit', unlit),
      app.runtimeMaterialsSupported ? throwsStateError : throwsUnsupportedError,
    );
  });

  const vertexSource = '''
material {
    name : RuntimeVertexVariables,
    shadingModel : unlit,
    requires : [ uv0 ],
    variables : [ runtimeUV ],
    variantFilter : [ skinning, shadowReceiver, vsm ],
    blending : transparent,
    parameters : [
        { type : float3, name : tint },
        { type : float, name : opacity }
    ]
}
vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        material.runtimeUV = vec4(material.uv0, 0.0, 1.0);
    }
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(materialParams.tint * variable_runtimeUV.x,
                materialParams.opacity);
    }
}
''';

  test('vertex variables, required UVs, variant filters and blending survive parsing', () async {
    if (!app.runtimeMaterialsSupported) {
      await expectLater(app.compileMaterialPackage('vertex_variables', vertexSource), throwsUnsupportedError);
      return;
    }
    final material = await app.compileMaterialPackage('vertex_variables', vertexSource);
    addTearDown(material.destroy);
    expect(await material.getBlendingMode(), BlendingMode.TRANSPARENT);
    expect(await material.hasParameter('tint'), isTrue);
    expect(await material.hasParameter('opacity'), isTrue);
    final instance = await material.createInstance();
    addTearDown(instance.destroy);
    await instance.setParameterFloat3('tint', 0.1, 0.2, 0.3);
    await instance.setParameterFloat('opacity', 0.4);
  });

  test('variantFilter rejects unknown variants', () async {
    final invalid = vertexSource.replaceFirst('skinning, shadowReceiver, vsm', 'notARealVariant');
    await expectLater(
      app.compileMaterialPackage('invalid_variant_filter', invalid),
      app.runtimeMaterialsSupported ? throwsStateError : throwsUnsupportedError,
    );
  });

  test('include cycles are rejected and leave the compiler usable', () async {
    await expectLater(
      app.compileMaterialPackage(
        'include_cycle',
        packageSource,
        includes: {'common.glsl': '#include "second.glsl"', 'second.glsl': '#include "common.glsl"'},
      ),
      app.runtimeMaterialsSupported ? throwsStateError : throwsUnsupportedError,
    );
    if (app.runtimeMaterialsSupported) {
      final material = await app.compileMaterialPackage('after_cycle', packageSource, includes: packageIncludes);
      await material.destroy();
    }
  });
}
