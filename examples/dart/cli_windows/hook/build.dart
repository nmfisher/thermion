import 'dart:io';
import 'package:logging/logging.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final logger = Logger("")
      ..level = Level.ALL
      ..onRecord.listen((record) => print(
          record.message + "\n"));
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    final targetOS = input.config.code.targetOS;

    final sources = <String>[];
    final defines = <String, String>{};
    final flags = <String>[];

    if (targetOS == OS.windows) {
      sources.add('native/thermion_window.cpp');
      defines['UNICODE'] = '1';
    } else if (targetOS == OS.linux) {
      sources.add('native/thermion_window_linux.cpp');
      flags.add('-std=c++17');

      final cflagsResult = await Process.run('pkg-config', ['--cflags', 'sdl2']);
      if (cflagsResult.exitCode == 0) {
        flags.addAll(cflagsResult.stdout.toString().trim().split(RegExp(r'\s+')));
      }
      final libsResult = await Process.run('pkg-config', ['--libs', 'sdl2']);
      if (libsResult.exitCode == 0) {
        flags.addAll(libsResult.stdout.toString().trim().split(RegExp(r'\s+')));
      }
    }

    final cbuilder = CBuilder.library(
      name: input.packageName,
      language: Language.cpp,
      assetName: 'cli_windows.dart',
      sources: sources,
      includes: ['native', '../../../thermion_dart/native/include'],
      defines: defines,
      flags: flags,
      dartBuildFiles: ['hook/build.dart'],
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: logger,
    );

  });
}
