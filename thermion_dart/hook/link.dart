import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import '../lib/src/logging/log.dart';

void main(List<String> args) async {
  await link(args, (LinkInput input, output) async {
    final packageRoot = input.packageRoot;
    var pkgRootFilePath = packageRoot.toFilePath(windows: Platform.isWindows);
    final logger = createBuildLogger(pkgRootFilePath, "link.log");

    // The CLinker.library(... LinkerOptions.manual(...)) call below
    // delegates to native_toolchain_c.runCl on Windows, which builds a
    // cl.exe command line from the constructor's `sources` list. Our
    // call passes no sources (the build hook already produced
    // thermion_dart.dll), so cl.exe is invoked with only flags and exits
    // immediately with `cl : Command line error D8003: missing source
    // filename`. The link phase is optional here — pass the build
    // hook's code assets through unchanged on Windows. Keep the
    // CLinker call on platforms where it currently works.
    if (input.config.code.targetOS == OS.windows) {
      for (final asset in input.assets.code) {
        output.assets.code.add(asset);
      }
      logger.info(
        "Link step skipped on Windows; passed through "
        "${input.assets.code.length} code asset(s).",
      );
      return;
    }

    final clinker = CLinker.library(
      name: "thermion_dart",
      linkerOptions: LinkerOptions.manual(stripDebug: false),
    );
    clinker.run(input: input, output: output, logger: logger);

    logger.info("Link step completed!");
  });
}
