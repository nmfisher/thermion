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
    final cbuilder = CBuilder.library(
      name: input.packageName,
      language: Language.cpp,
      assetName: 'cli_windows.dart',
      sources: ['native/thermion_window.cpp'],
      includes: ['native', '../../../thermion_dart/native/include'],
      defines: {"UNICODE":"1"},
      flags:[],
      dartBuildFiles: ['hook/build.dart'],
      
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: logger,
    );

  });
}

