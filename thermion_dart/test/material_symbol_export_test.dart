import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thermion_dart/src/hooks/material_tools.dart';

List<String> llvmDirectories() {
  final directories = <String>[];
  final roots = <String>[
    if (Platform.environment['ANDROID_NDK_HOME'] case final String root) root,
    if (Platform.environment['ANDROID_NDK_ROOT'] case final String root) root,
  ];
  for (final sdk in [
    Platform.environment['ANDROID_HOME'],
    Platform.environment['ANDROID_SDK_ROOT'],
    if (Platform.isMacOS) p.join(Platform.environment['HOME']!, 'Library', 'Android', 'sdk'),
  ]) {
    if (sdk == null) continue;
    final ndks = Directory(p.join(sdk, 'ndk'));
    if (ndks.existsSync()) roots.addAll(ndks.listSync().whereType<Directory>().map((dir) => dir.path));
  }
  for (final root in roots) {
    final hosts = Directory(p.join(root, 'toolchains', 'llvm', 'prebuilt'));
    if (hosts.existsSync())
      directories.addAll(hosts.listSync().whereType<Directory>().map((dir) => p.join(dir.path, 'bin')));
  }
  return directories;
}

String? tool(String name, List<String> directories) {
  for (final candidate in [
    for (final dir in directories) p.join(dir, name + (Platform.isWindows ? '.exe' : '')),
    name,
  ]) {
    try {
      if (Process.runSync(candidate, ['--version']).exitCode == 0) return candidate;
    } on ProcessException {
      /* Try the next installed toolchain. */
    }
  }
  return null;
}

void main() {
  final directories = llvmDirectories();
  final clang = tool('clang++', directories);
  final elfLinker = tool('ld.lld', directories);
  final peLinker = tool('lld-link', directories);
  final reader = tool('llvm-readobj', directories);
  final available = [clang, elfLinker, peLinker, reader].every((tool) => tool != null);
  final localSkip = !available && Platform.environment['CI'] != 'true';

  for (final windows in [false, true]) {
    test(
      '${windows ? 'Windows DLL' : 'Android ELF'} exports generated data symbols',
      () async {
        expect(available, isTrue, reason: 'Install LLVM clang/lld/llvm-readobj or an Android NDK');
        final root = Directory.systemTemp.createTempSync('material-exports-');
        addTearDown(() => root.deleteSync(recursive: true));
        final include = Directory(p.join(root.path, 'includes'))..createSync();
        File(p.join(include.path, 'stdint.h')).writeAsStringSync('typedef unsigned char uint8_t;\n');
        final source = File(p.join(root.path, 'skin.c'))
          ..writeAsStringSync('''#include "skin.h"
const uint8_t SKIN_PACKAGE[] = {7,8,9};
const int SKIN_PACKAGE_SIZE = 3;
''');
        File(p.join(root.path, 'skin.h')).writeAsStringSync('''#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
extern const uint8_t SKIN_PACKAGE[];
extern const int SKIN_PACKAGE_SIZE;
#ifdef __cplusplus
}
#endif
''');
        final object = p.join(root.path, windows ? 'skin.obj' : 'skin.o');
        final library = p.join(root.path, windows ? 'skin.dll' : 'libskin.so');
        Future<String> run(String executable, List<String> arguments) async {
          final result = await Process.run(executable, arguments);
          expect(result.exitCode, 0, reason: '$executable ${arguments.join(' ')}\n${result.stdout}\n${result.stderr}');
          return '${result.stdout}';
        }

        Future<String> exports() async {
          await run(clang!, [
            '--target=${windows ? 'x86_64-pc-windows-msvc' : 'aarch64-linux-android21'}',
            '-x',
            'c++',
            '-std=c++17',
            '-ffreestanding',
            '-fno-exceptions',
            '-fno-rtti',
            '-fvisibility=hidden',
            '-fdata-sections',
            '-nostdinc',
            '-I',
            include.path,
            '-c',
            source.path,
            '-o',
            object,
          ]);
          if (windows) {
            await run(peLinker!, ['/dll', '/noentry', '/nodefaultlib', '/out:$library', object]);
            return run(reader!, ['--coff-exports', library]);
          }
          await run(elfLinker!, ['-shared', '--gc-sections', '-o', library, object]);
          return run(reader!, ['--dyn-symbols', '--elf-output-style=GNU', library]);
        }

        // External C linkage by itself is insufficient: reproduce the old output.
        final before = await exports();
        expect(before, isNot(contains('SKIN_PACKAGE')));
        patchResgenOutput(root, log: (_) {});
        final after = await exports();
        for (final name in ['SKIN_PACKAGE', 'SKIN_PACKAGE_SIZE']) {
          final symbol = windows ? RegExp('Name: $name\\s') : RegExp('GLOBAL\\s+DEFAULT\\s+\\S+\\s+$name\\s');
          expect(after, matches(symbol), reason: after);
        }
      },
      skip: localSkip ? 'LLVM cross tools not installed' : false,
    );
  }
}
