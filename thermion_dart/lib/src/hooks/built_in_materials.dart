import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../filament_version.dart';
import '../filament/src/interface/built_in_material.dart';
import 'filament_artifacts.dart';
import 'material_publication.dart';
import 'material_tools.dart';
import 'web_artifacts.dart';

List<BuiltInMaterial> selectBuiltInMaterials(Object? materialConfig, {required void Function(String) onWarning}) {
  if (materialConfig == null) return [];
  if (materialConfig is! Map) {
    throw MaterialToolsError('materials must be a map in pubspec.yaml.');
  }
  // unlit_fallback is hook-managed (compiled only for features.gltf:
  // false builds), never a user-selectable materials.* key.
  final knownMaterialKeys = {
    'backends',
    ...BuiltInMaterial.values.where((m) => m != BuiltInMaterial.unlitFallback).map((material) => material.key),
  };
  for (final MapEntry(:key, :value) in materialConfig.entries) {
    if (!knownMaterialKeys.contains(key)) {
      onWarning('Unknown key materials.$key in pubspec.yaml.');
    } else if (key != 'backends' && value is! bool) {
      throw MaterialToolsError('materials.$key must be true or false (an unquoted YAML boolean).');
    }
  }
  return [
    for (final material in BuiltInMaterial.values)
      if (material != BuiltInMaterial.unlitFallback && materialConfig[material.key] == true) material,
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

/// Compiles the unlit fallback material into a resgen C blob for a native
/// `features.gltf: false` build, with the same version-matched matc/resgen
/// pipeline and cache layout as [compileBuiltInMaterials].
///
/// Returns the output directory holding `unlit_fallback.c`/`unlit_fallback.h`
/// (symbols `UNLIT_FALLBACK_UNLIT_FALLBACK_DATA`/`_SIZE`, consumed by
/// TMaterialInstance.cpp under UNLIT_FALLBACK_ENABLED; Dart builds the
/// package through Material_createBuiltIn(BUILT_IN_UNLIT_FALLBACK)).
/// Default builds never call this, so they pay no matc/resgen step for it.
Future<Directory> compileUnlitFallbackMaterial({
  required Directory root,
  required List<String> backends,
  required void Function(String) onLog,
  UrlDownloader? download,
  void Function(Uri)? addDependency,
}) async {
  final packageVersion = await readPubspecVersion(root);
  final hostArch = await detectHostArchitecture() ?? 'x64';
  final pinFile = File(path.join(root.path, filamentPinFileName));
  final warnings = <String>[];
  final toolsPin = parseFilamentPin(pinFile.existsSync() ? pinFile.readAsStringSync() : null, warnings: warnings);
  warnings.forEach(onLog);
  final variantKey = '${backends.join('_')}-resgen';
  final cacheDir = path.join(
    root.path,
    '.dart_tool',
    'thermion_dart',
    'materials',
    unlitFallbackMaterialKey,
    variantKey,
  );
  final result = await compileUserMaterials(
    appRoot: root,
    config: MaterialCompilationConfig(
      inputs: ['hook/materials/$unlitFallbackMaterialKey.mat'],
      output: cacheDir,
      backends: backends,
      resgen: true,
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
    if (depPath != normalizedCache && !path.isWithin(normalizedCache, depPath)) {
      addDependency?.call(uri);
    }
  }
  addDependency?.call(root.uri.resolve('pubspec.yaml'));
  addDependency?.call(pinFile.uri);
  return result.outputDir;
}

/// Compiles and stages the built-in materials for a web build.
///
/// [backend] is the resolved `backend` user define for the web target: it
/// picks the shader formats embedded into the staged engine. WebGL2 uses
/// GLSL, WebGPU uses WGSL, and hybrid builds include both.
Future<void> publishWebMaterials({
  required Directory root,
  required Directory engineDir,
  required Directory webDir,
  required List<BuiltInMaterial> materials,
  required void Function(String) onLog,
  String backend = defaultWebBackend,
  UrlDownloader? download,
  void Function(Uri)? addDependency,
}) async {
  final compiled = await compileBuiltInMaterials(
    backends: webMaterialBackends(backend),
    resgen: false,
    root: root,
    materials: materials,
    download: download,
    onLog: onLog,
    addDependency: addDependency,
  );
  await stageWebEngine(engineDir, webDir, {
    for (final MapEntry(key: material, value: dir) in compiled.entries)
      material: File(path.join(dir.path, '${material.key}.filamat')),
  }, onLog: onLog);
  for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
    addDependency?.call(File(path.join(engineDir.path, name)).uri);
    addDependency?.call(File(path.join(webDir.path, name)).uri);
  }
}

// WebAssembly section lengths and UTF-8 name lengths are unsigned LEB128.
List<int> _encodeLength(int value) {
  final bytes = <int>[];
  do {
    final low = value & 0x7f;
    value >>= 7;
    bytes.add(value == 0 ? low : low | 0x80);
  } while (value != 0);
  return bytes;
}

/// Publish the loader and customized Wasm together, always starting with the
/// pristine engine. The hook and CLI share a lock per destination.
Future<void> stageWebEngine(
  Directory engineDir,
  Directory webDir,
  Map<BuiltInMaterial, File> packages, {
  required void Function(String) onLog,
}) async {
  const js = 'thermion_dart.js';
  const wasm = 'thermion_dart.wasm';
  webDir.createSync(recursive: true);
  if (FileSystemEntity.identicalSync(engineDir.path, webDir.path)) {
    throw ArgumentError('The web output directory must be different from the base engine directory.');
  }
  final destination = webDir.resolveSymbolicLinksSync();
  final lockKey = sha256.convert(utf8.encode(destination)).toString();
  final lockDir = Directory(path.join(Directory.systemTemp.path, 'thermion-web-engine-locks', lockKey));
  await withMaterialOutputLock(lockDir, () async {
    // User-authored material compilation can also publish into web/. Keep its
    // journal and staged files independent of the JS/Wasm pair.
    final state = Directory(path.join(webDir.path, '.thermion-web-engine'))..createSync();
    recoverMaterialPublication(webDir, stateDirectory: state);
    final stage = state.createTempSync(materialStagingPrefix);
    try {
      File file(Directory dir, String name) => File(path.join(dir.path, name));
      file(engineDir, js).copySync(file(stage, js).path);
      final binary = file(engineDir, wasm).copySync(file(stage, wasm).path);
      final output = binary.openSync(mode: FileMode.append);
      try {
        for (final material in BuiltInMaterial.values) {
          final package = packages[material];
          if (package == null) continue;
          final bytes = package.readAsBytesSync();
          final name = utf8.encode(material.wasmSectionName);
          final nameLength = _encodeLength(name.length);
          output.writeFromSync([
            0,
            ..._encodeLength(nameLength.length + name.length + bytes.length),
            ...nameLength,
            ...name,
          ]);
          output.writeFromSync(bytes);
        }
      } finally {
        output.closeSync();
      }
      Future<bool> changed(String name) async {
        final before = file(webDir, name);
        final after = file(stage, name);
        if (!before.existsSync() || before.lengthSync() != after.lengthSync()) return true;
        return await sha256.bind(before.openRead()).first != await sha256.bind(after.openRead()).first;
      }

      if (await changed(js) || await changed(wasm)) {
        publishMaterialBatch(
          output: webDir,
          staging: stage,
          stateDirectory: state,
          outputs: [js],
          staleOutputs: [],
          manifestName: wasm,
          log: onLog,
        );
      }
      // Older builds deployed these files beside the engine. Keep user-owned files.
      final legacy = Directory(path.join(webDir.path, 'thermion_materials'));
      if (legacy.existsSync()) {
        for (final material in BuiltInMaterial.values) {
          final old = file(legacy, '${material.key}.filamat');
          if (old.existsSync()) old.deleteSync();
        }
        if (legacy.listSync().isEmpty) legacy.deleteSync();
      }
    } finally {
      if (!File(path.join(state.path, materialJournalName)).existsSync() && stage.existsSync()) {
        stage.deleteSync(recursive: true);
      }
      if (state.listSync().isEmpty) state.deleteSync();
    }
  });
}
