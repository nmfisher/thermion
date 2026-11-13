import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'real hook runner invalidates discovery, includes, outputs and the manifest',
    () async {
      final package = Directory.current.absolute;
      final root = Directory.systemTemp.createTempSync('material-hook-runner-');
      addTearDown(() => root.deleteSync(recursive: true));
      final fixture = Directory('test/fixtures/material_hook_app');
      for (final entity in fixture.listSync(recursive: true)) {
        if (entity is! File) continue;
        final destination = File(p.join(root.path, p.relative(entity.path, from: fixture.path)));
        destination.parent.createSync(recursive: true);
        entity.copySync(destination.path);
      }
      final pubspec = File(p.join(root.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync(
        pubspec.readAsStringSync().replaceFirst('path: ../../..', 'path: ${jsonEncode(package.path)}'),
      );
      File(
        p.join(root.path, 'test_tools.dart'),
      ).writeAsStringSync("export '${package.uri.resolve('test/material_tools_test.dart')}' show FakeTools;\n");
      File write(String name, String text) {
        final file = File(p.join(root.path, name));
        file.parent.createSync(recursive: true);
        return file..writeAsStringSync(text);
      }

      write('materials/skin.mat', '#include "nested/common.glsl"');
      final include = write('materials/nested/common.glsl', 'first');
      Future<void> command(List<String> arguments) async {
        final result = await Process.run(Platform.resolvedExecutable, arguments, workingDirectory: root.path);
        expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      }

      int runs() => File(p.join(root.path, 'hook-runs.txt')).readAsLinesSync().length;
      int compiled() =>
          (jsonDecode(File(p.join(root.path, 'last-result.json')).readAsStringSync()) as Map)['compiled'] as int;
      Future<void> settle() async {
        // Self-produced dependencies can need a cache warm-up after their write.
        var previous = -1;
        for (var i = 0; i < 8; i++) {
          await command(['run', 'bin/main.dart']);
          final count = runs();
          if (previous == count) return;
          previous = count;
        }
        fail('hook did not reach a stable cache');
      }

      Future<void> changed(void Function() edit, int expectedCompiles) async {
        final before = runs();
        edit();
        await command(['run', 'bin/main.dart']);
        expect(runs(), greaterThan(before), reason: 'hook runner incorrectly reused its cached result');
        expect(compiled(), expectedCompiles);
        await settle();
      }

      await command(['pub', 'get', '--offline']);
      await settle();
      await changed(() => write('materials/eye.mat', 'eye'), 1);
      await changed(() => write('materials/new/deep/new.mat', 'new'), 1);
      await changed(() => write('materials/new/deep/another.mat', 'another'), 1);
      await changed(() => include.writeAsStringSync('changed transitive include'), 1);
      await changed(() => File(p.join(root.path, 'out/skin.filamat')).deleteSync(), 1);
      await changed(() => File(p.join(root.path, 'out/eye.filamat')).writeAsStringSync('corrupt'), 1);
      await changed(() => File(p.join(root.path, 'materials/eye.mat')).deleteSync(), 0);
      expect(File(p.join(root.path, 'out/eye.filamat')).existsSync(), isFalse);
      await changed(() => File(p.join(root.path, 'out/.thermion-materials.json')).deleteSync(), 3);
      pubspec.writeAsStringSync(
        pubspec.readAsStringSync().replaceFirst('inputs: [materials]', 'inputs: [materials/**/*.mat]'),
      );
      await settle();
      await changed(() => write('materials/new/deep/glob.mat', 'new glob match'), 1);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
