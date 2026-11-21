import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:thermion_dart/src/hooks/material_tools.dart';
import '../material_tools_test.dart' show FakeTools;

Future<void> main(List<String> args) async {
  final shared = Directory(args[0]);
  final id = args[1];
  final root = Directory(p.join(shared.path, 'app-$id'))..createSync();
  File(p.join(root.path, 'skin.mat')).writeAsStringSync('skin');
  File(p.join(shared.path, 'ready-$id')).writeAsStringSync('ready');
  while (!File(p.join(shared.path, 'start')).existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final tools = FakeTools();
  final result = await compileUserMaterials(
    appRoot: root,
    config: parseMaterialCompilationConfig({
      'inputs': ['skin.mat'],
      'output': 'out',
    })!,
    filamentVersion: 'v1.77.2',
    packageVersion: 'test',
    hostOS: 'linux',
    hostArch: 'x64',
    toolsCacheRoot: p.join(shared.path, 'cache'),
    download: (url, file) async {
      File(p.join(shared.path, 'download-$id')).writeAsStringSync(file.path);
      while (!File(p.join(shared.path, 'finish-download')).existsSync()) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await tools.downloader()(url, file);
    },
    runProcess: tools.run,
  );
  print('compiled=${result.compiled}');
}
