import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:thermion_dart/src/hooks/material_tools.dart';
import '../material_tools_test.dart' show FakeTools;

void main(List<String> args) async {
  final root = Directory(args[0]);
  final tools = FakeTools();
  Future<ToolRunResult> runner(String executable, List<String> arguments) async {
    final result = await tools.run(executable, arguments);
    if (executable.endsWith('matc') && p.basename(arguments.last) != 'smoke.mat' && result.exitCode == 0) {
      File(arguments[arguments.indexOf('-o') + 1]).writeAsStringSync(File(arguments.last).readAsStringSync());
    }
    return result;
  }

  final result = await compileUserMaterials(
    appRoot: root,
    config: parseMaterialCompilationConfig({
      'inputs': ['materials'],
      'output': 'out',
    })!,
    filamentVersion: 'v1.77.2',
    packageVersion: 'test',
    hostOS: 'macos',
    hostArch: 'arm64',
    toolsCacheRoot: p.join(root.path, 'tools'),
    download: tools.downloader(),
    runProcess: runner,
    onLog: (message) {
      if (args.contains('interrupt') && message.contains('published ')) exit(75);
    },
  );
  print('compiled=${result.compiled}');
}
