import 'dart:io';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {

  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    // thermion_dart's hook skips metadata when not building code assets
    // (e.g. web builds); there's no native CMake step to feed in that case.
    // Matches code_assets's buildCodeAssets getter without importing that
    // package just for a single gate.
    if (!input.config.buildAssetTypes.contains('code_assets/code')) {
      return;
    }

    final includeDirs = (input.metadata["thermion_dart"]["includeDirs"] as List).cast<String>();
    final cmakeSafePath = includeDirs.map((dir) => dir.replaceAll('\\', '/')).map((dir) => '"$dir"').join(" ");
    final cmakeContent = 'set(DART_PKG_HEADERS $cmakeSafePath)';

    final outfile = File.fromUri(input.packageRoot.resolve('.dart_tool/generated_headers.cmake'));
    if(!outfile.parent.existsSync()) {
      outfile.parent.createSync();
    }
    await outfile.writeAsString(cmakeContent);

  });
}