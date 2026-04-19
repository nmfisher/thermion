import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import 'log.dart';

void main(List<String> args) async {
  await link(args, (LinkInput input, output) async {
    final packageRoot = input.packageRoot;
    var pkgRootFilePath = packageRoot.toFilePath(windows: Platform.isWindows);
    final logger = createLogger(pkgRootFilePath, "link.log");

    final clinker = CLinker.library(
        name: "thermion_dart",
        linkerOptions: LinkerOptions.manual(stripDebug: false));
    clinker.run(input: input, output: output, logger: logger);

    logger.info("Link step completed!");
  });
}
