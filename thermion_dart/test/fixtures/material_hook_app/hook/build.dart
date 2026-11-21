import 'dart:convert';
import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:thermion_dart/src/hooks/material_tools.dart';
import '../test_tools.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final root = Directory.fromUri(input.packageRoot);
    File('${root.path}/hook-runs.txt').writeAsStringSync('run\n', mode: FileMode.append);
    final tools = FakeTools();
    final result = await compileUserMaterials(
      appRoot: root,
      config: parseMaterialCompilationConfig(input.userDefines['material_compilation'])!,
      filamentVersion: 'v1.77.2',
      packageVersion: 'test',
      hostOS: Platform.operatingSystem,
      hostArch: 'x64',
      toolsCacheRoot: '${root.path}/tools',
      download: tools.downloader(),
      runProcess: tools.run,
    );
    output.dependencies.addAll(result.dependencies);
    File('${root.path}/last-result.json').writeAsStringSync(
      jsonEncode({
        'compiled': result.compiled,
        'skipped': result.skipped,
        'inputs': result.inputs.map((f) => f.path).toList(),
      }),
    );
  });
}
