import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../filament_version.dart';
import '../filament/src/interface/built_in_material.dart';
import 'filament_artifacts.dart';
import 'material_publication.dart';
import 'material_tools.dart';

List<BuiltInMaterial> selectBuiltInMaterials(Object? materialConfig, {required void Function(String) onWarning}) {
  if (materialConfig == null) return [];
  if (materialConfig is! Map) {
    throw MaterialToolsError('materials must be a map in pubspec.yaml.');
  }
  final knownMaterialKeys = {'backends', ...BuiltInMaterial.values.map((material) => material.key)};
  for (final MapEntry(:key, :value) in materialConfig.entries) {
    if (!knownMaterialKeys.contains(key)) {
      onWarning('Unknown key materials.$key in pubspec.yaml.');
    } else if (key != 'backends' && value is! bool) {
      throw MaterialToolsError('materials.$key must be true or false (an unquoted YAML boolean).');
    }
  }
  return [
    for (final material in BuiltInMaterial.values)
      if (materialConfig[material.key] == true) material,
  ];
}

Future<Map<BuiltInMaterial, Directory>> compileBuiltInMaterials({
  required Directory root,
  required List<BuiltInMaterial> materials,
  required List<String> backends,
  required bool resgen,
  required void Function(String) onLog,
  UrlDownloader? download,
  void Function(Uri)? addDependency,
}) async {
  if (materials.isEmpty) return {};
  final packageVersion = await readPubspecVersion(root);
  final hostArch = await detectHostArchitecture() ?? 'x64';
  final pinFile = File(path.join(root.path, filamentPinFileName));
  final warnings = <String>[];
  final toolsPin = parseFilamentPin(pinFile.existsSync() ? pinFile.readAsStringSync() : null, warnings: warnings);
  warnings.forEach(onLog);
  final variantKey = '${backends.join('_')}-${resgen ? 'resgen' : 'filamat'}';
  final outputs = <BuiltInMaterial, Directory>{};

  for (final material in materials) {
    final cacheDir = path.join(root.path, '.dart_tool', 'thermion_dart', 'materials', material.key, variantKey);
    final result = await compileUserMaterials(
      appRoot: root,
      config: MaterialCompilationConfig(
        inputs: ['hook/materials/${material.key}.mat'],
        output: cacheDir,
        backends: backends,
        resgen: resgen,
        resgenPrefixes: material.resgenPrefix != material.key ? {material.key: material.resgenPrefix} : const {},
      ),
      filamentVersion: filamentVersion,
      packageVersion: packageVersion,
      hostOS: Platform.operatingSystem,
      hostArch: hostArch,
      toolsPin: toolsPin,
      download: download,
      onLog: onLog,
    );
    final normalizedCache = path.normalize(cacheDir);
    for (final uri in result.dependencies) {
      final depPath = path.normalize(uri.toFilePath(windows: Platform.isWindows));
      // Register input dependencies (.mat sources, transitive #includes, matc)
      // but not files written by this hook under cacheDir (which would trigger
      // hooks_runner's "File modified during build" warning on cold builds).
      if (depPath != normalizedCache && !path.isWithin(normalizedCache, depPath)) {
        addDependency?.call(uri);
      }
    }
    outputs[material] = result.outputDir;
  }

  addDependency?.call(root.uri.resolve('pubspec.yaml'));
  addDependency?.call(pinFile.uri);
  return outputs;
}

/// Publish the selected packages beside the web entrypoint. Compile the whole
/// selection before changing any deployed files, so a matc failure is retryable.
Future<void> publishWebMaterials({
  required Directory root,
  required Directory webDir,
  required List<BuiltInMaterial> materials,
  required void Function(String) onLog,
  UrlDownloader? download,
  void Function(Uri)? addDependency,
}) async {
  final compiled = await compileBuiltInMaterials(
    root: root,
    materials: materials,
    backends: const ['opengl', 'webgpu'],
    resgen: false,
    download: download,
    onLog: onLog,
    addDependency: addDependency,
  );
  final deployDir = Directory(path.join(webDir.path, 'thermion_materials'));
  if (compiled.isEmpty && !deployDir.existsSync()) return;

  // Calls from the hook and CLI share this cache. Serialize the final copy
  // and prune so concurrent invocations cannot mix two selections.
  final cache = Directory(path.join(root.path, '.dart_tool', 'thermion_dart', 'materials'));
  await withMaterialOutputLock(cache, () async {
    for (final dependency in stageWebMaterialFiles(deployDir, compiled, onLog: onLog)) {
      addDependency?.call(dependency);
    }
  });
}

/// Track deployed files as hook dependencies so deleting or changing one
/// invalidates a cached web build.
List<Uri> stageWebMaterialFiles(
  Directory deployDir,
  Map<BuiltInMaterial, Directory> compiled, {
  void Function(String)? onLog,
}) {
  final dependencies = <Uri>[];
  if (compiled.isNotEmpty) deployDir.createSync(recursive: true);
  for (final MapEntry(key: material, value: output) in compiled.entries) {
    final name = '${material.key}.filamat';
    final source = File(path.join(output.path, name));
    final destination = File(path.join(deployDir.path, name));
    if (!destination.existsSync() ||
        sha256.convert(source.readAsBytesSync()) != sha256.convert(destination.readAsBytesSync())) {
      source.copySync(destination.path);
      onLog?.call('Published $name to ${destination.path}');
    }
    dependencies.add(destination.uri);
  }
  for (final material in BuiltInMaterial.values.where((material) => !compiled.containsKey(material))) {
    final destination = File(path.join(deployDir.path, '${material.key}.filamat'));
    if (destination.existsSync()) destination.deleteSync();
  }
  if (deployDir.existsSync()) dependencies.add(deployDir.uri);
  return dependencies;
}
