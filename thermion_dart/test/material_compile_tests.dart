import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

/// Returns the RGBA float at (x, y) of a captured float pixel buffer.
List<double> pixelAt(Float32List buffer, int width, int height, int x, int y) {
  final offset = (y * width + x) * 4;
  return [buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3]];
}

/// Pulls the parameter names out of a .mat source's `parameters` block, so a
/// golden compile can be checked for more than "it didn't throw".
Set<String> parameterNames(String source) {
  final blockStart = source.indexOf("parameters");
  if (blockStart < 0) {
    return {};
  }
  final blockEnd = source.indexOf("]", blockStart);
  final block =
      source.substring(blockStart, blockEnd < 0 ? source.length : blockEnd);
  return RegExp(r"name\s*:\s*([A-Za-z_][A-Za-z0-9_]*)")
      .allMatches(block)
      .map((m) => m.group(1)!)
      .toSet();
}

/// A minimal parameterised unlit material, with [fragmentExtra] spliced into
/// the fragment shader so tests can vary the compiled output.
String colorMaterial(String fragmentExtra) => """
material {
    name : RuntimeCompileColor,
    requires : [ position ],
    parameters : [
        {
            type : float4,
            name : color
        }
    ],
    shadingModel : unlit,
    blending : opaque,
    culling : none,
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.color;
        $fragmentExtra
    }
}
""";

void main() async {
  final testHelper = TestHelper("material_compile");
  await testHelper.setup();

  final app = FilamentApp.instance!;

  // The shipped .mat sources — exactly what materials/build.sh compiles.
  // (materials/ also holds unlit/depth_sampler/vdtm sources that the build
  // does not ship; vdtm.mat is outright broken — `z` declared inside an if
  // block and used outside — and would fail under matc too.)
  final workspaceMaterials =
      p.normalize(p.join(testHelper.assetsDir, "..", "..", "materials"));
  final shippedNames = [
    "bone_overlay",
    "capture_uv",
    "edge_outline",
    "gizmo",
    "grid",
    "image",
    "linear_depth",
    "silhouette",
    "translation_axis",
    "unlit_fixed_size",
    "wireframe",
  ];
  final exampleMaterials = [
    "customattributes.mat",
    "solidcolor.mat",
    "viewspace.mat",
  ].map((name) => p.join(testHelper.assetsDir, name)).toList();
  final allShipped = [
    ...shippedNames.map((name) => p.join(workspaceMaterials, "$name.mat")),
    ...exampleMaterials,
  ];

  test("golden: runtime compile accepts every shipped .mat", () async {
    await testHelper.withViewer((viewer) async {
      final failures = <String>[];
      for (final path in allShipped) {
        final source = File(path).readAsStringSync();
        try {
          final compiled = await app.compileMaterial(
            source,
            includePaths: [workspaceMaterials],
          );
          if (compiled.isEmpty) {
            failures.add("$path compiled to an empty package");
            continue;
          }
          final material = await app.createMaterial(compiled);
          for (final param in parameterNames(source)) {
            if (!await material.hasParameter(param)) {
              failures.add("$path lost parameter $param in the runtime compile");
            }
          }
          await material.destroy();
        } catch (e) {
          failures.add("$path: $e");
        }
      }
      // Report every failing file at once: a single thrown exception would
      // hide the state of the files after it.
      expect(failures, isEmpty, reason: failures.join("\n"));
    });
  });

  test("parse errors surface the compiler's message", () async {
    await testHelper.withViewer((viewer) async {
      await expectLater(
        app.compileMaterial("material { this is not a valid material }"),
        throwsA(isA<MaterialCompileException>().having(
          (e) => e.message,
          "message",
          isNotEmpty,
        )),
      );
    });
  });

  test("explicit target APIs produce loadable packages", () async {
    await testHelper.withViewer((viewer) async {
      // Compile for a single backend rather than deriving from the engine —
      // the output must still be a valid package for Material::Builder.
      final compiled = await app.compileMaterial(
        colorMaterial(""),
        targetApi: {MaterialTargetApi.opengl},
        platform: MaterialCompilePlatform.desktop,
        optimization: MaterialOptimization.size,
      );
      final material = await app.createMaterial(compiled);
      expect(await material.hasParameter("color"), isTrue);
      await material.destroy();
    });
  });

  test("defines reach the shader preprocessor", () async {
    await testHelper.withViewer((viewer) async {
      final source = """
material {
    name : DefinesMaterial,
    requires : [ position ],
    parameters : [
        {
            type : float,
            name : factor
        }
    ],
    shadingModel : unlit,
    blending : opaque,
    culling : none,
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
#ifdef TINT_RED
        material.baseColor = float4(1.0, 0.0, 0.0, 1.0);
#else
        material.baseColor = float4(0.0, 0.0, 1.0, 1.0);
#endif
    }
}
""";
      final withoutDefine = await app.compileMaterial(source);
      final withDefine =
          await app.compileMaterial(source, defines: {"TINT_RED": "1"});
      expect(withoutDefine, isNotEmpty);
      expect(withDefine, isNotEmpty);
      // Both variants load; they are different packages (different shaders).
      expect(withDefine, isNot(equals(withoutDefine)));

      final material = await app.createMaterial(withDefine);
      expect(await material.hasParameter("factor"), isTrue);
      await material.destroy();
    });
  });

  group("include resolution", () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync("thermion_includes");
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test("nested includes are flattened", () async {
      await testHelper.withViewer((viewer) async {
        // Includes live inside shader blocks (matp's grammar only accepts
        // the material document at the top level — same restriction matc's
        // own include preprocessing has).
        File(p.join(tmp.path, "outer.h")).writeAsStringSync(
            "#include \"inner.h\"\nfloat tweak(float v) { return v * HALF; }\n");
        File(p.join(tmp.path, "inner.h")).writeAsStringSync(
            "#define HALF (0.5)\n#define DOUBLE_IT(v) ((v) * 2.0)\n");
        final source = """
material {
    name : IncludeMaterial,
    requires : [ position ],
    shadingModel : unlit,
    blending : opaque,
    culling : none,
}
fragment {
#include "outer.h"
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = float4(tweak(DOUBLE_IT(0.25)));
    }
}
""";
        final compiled =
            await app.compileMaterial(source, includePaths: [tmp.path]);
        expect(compiled, isNotEmpty);
        final material = await app.createMaterial(compiled);
        await material.destroy();
      });
    });

    test("missing includes throw with the offending name", () async {
      await testHelper.withViewer((viewer) async {
        await expectLater(
          app.compileMaterial(
              '#include "does_not_exist.h"\nmaterial { }', includePaths: [tmp.path]),
          throwsA(isA<MaterialCompileException>().having(
              (e) => e.message, "message", contains("does_not_exist.h"))),
        );
      });
    });

    test("circular includes are detected", () async {
      await testHelper.withViewer((viewer) async {
        File(p.join(tmp.path, "loop.h")).writeAsStringSync('#include "loop.h"\n');
        await expectLater(
          app.compileMaterial('#include "loop.h"\nmaterial { }',
              includePaths: [tmp.path]),
          throwsA(isA<MaterialCompileException>().having(
              (e) => e.message, "message", contains("circular"))),
        );
      });
    });
  });

  test("compiled materials drive geometry and hot-reload end to end", () async {
    await testHelper.withViewer((viewer) async {
      const width = 512;
      const height = 512;

      final material =
          await app.createMaterial(await app.compileMaterial(colorMaterial("")));
      final instance = await material.createInstance();
      await instance.setParameterFloat4("color", 0.0, 0.0, 1.0, 1.0);
      final cube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [instance],
      );

      Future<List<double>> center() async {
        final pixels = (await testHelper.capture(viewer.view, "compile_e2e"))[viewer.view]!;
        return pixelAt(
            pixels.buffer.asFloat32List(), width, height, width ~/ 2, height ~/ 2);
      }

      final before = await center();
      expect(before[2], greaterThan(0.4), reason: "runtime-compiled material renders blue");
      expect(before[0], lessThan(0.1));

      // Recompile with the fragment forcing red, then hot-swap the package.
      final recompiled = await app.compileMaterial(
          colorMaterial("material.baseColor = float4(1.0, 0.0, 0.0, 1.0);"));
      final reloaded = await app.reloadMaterialFromBytes(material, recompiled);

      final after = await center();
      expect(after[0], greaterThan(0.4), reason: "recompiled material renders red");
      expect(after[2], lessThan(0.1));

      await viewer.destroyAsset(cube);
      await reloaded.destroy();
    });
  });
}
