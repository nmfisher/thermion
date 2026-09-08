import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await CBuilder.library(
      name: input.packageName,
      assetName: 'bindings.g.dart',
      sources: ['matrix_getters.c'],
      optimizationLevel: OptimizationLevel.o3,
    ).run(input: input, output: output);
  });
}
