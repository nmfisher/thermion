import 'dart:io';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {

  await build(args, (BuildInput input, BuildOutputBuilder output) async {
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