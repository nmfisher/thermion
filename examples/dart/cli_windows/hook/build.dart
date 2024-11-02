import 'dart:io';
import 'package:archive/archive.dart';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  final logger = Logger("")
      ..level = Level.ALL
      ..onRecord.listen((record) => print(
          record.message + "\n"));

  await build(args, (config, output) async {
    final cbuilder = CBuilder.library(
      name: "thermion_window",
      language: Language.cpp,
      assetName: 'thermion_window.dart',
      sources: ['native/thermion_window.cpp'],
      includes: ['native'],
      defines: {"UNICODE":"1"},
      flags:[],
      dartBuildFiles: ['hook/build.dart'],
    );

    await cbuilder.run(
      buildConfig: config,
      buildOutput: output,
      logger: logger,
    );
  });
}

