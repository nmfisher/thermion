/// Host-side (re)compilation of the embedded materials via matc/resgen.
///
/// Implements issue #399: the Dart build hook downloads the WebGPU-capable
/// `matc`/`resgen` pair matching the Filament version pinned in
/// `filament.version` from R2 (for the HOST platform, not the target), then
/// regenerates every material variant `materials/build.sh` emits into a
/// cache under `.dart_tool/`. A fingerprint over `filament.version` + the
/// `.mat` sources + the variant table makes repeat builds a no-op, so a
/// Filament version bump regenerates materials automatically and nothing
/// recompiles when nothing changed.
///
/// Kept free of build-hook imports and structured around injectable I/O
/// (downloader, process runner) so it can be unit tested without network
/// access or real matc binaries — see test/material_tools_test.dart. The
/// build hook wires it up in hook/build.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// R2 base for all prebuilt artifacts (Filament libs, web engine zips and
/// the Filament release zips that carry the shader tools). Same host as
/// webR2BaseUrl in web_artifacts.dart.
const String materialToolsR2BaseUrl = 'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev';

/// Bumped whenever the generation pipeline itself changes shape (variant
/// flag table, header rewriting rules, manifest schema). Part of the
/// fingerprint so an old cache can never satisfy a new pipeline.
const int materialPipelineVersion = 1;

/// Name of the gate file written next to the generated `material/` dir.
const String materialManifestName = 'manifest.json';

/// A material variant: the suffix appended to the generated files and the
/// matc architecture flags it is compiled with.
typedef MaterialVariant = ({String suffix, List<String> matcFlags});

/// Every variant each material is compiled into, in the exact order
/// `materials/build.sh` emits them. The order is load-bearing for
/// byte-identical output: resgen's unsuffixed `.S`/`.apple.S`/`.bin`
/// byproducts are overwritten per variant, so they must end up coming from
/// the same (last) variant as the committed artifacts.
const List<MaterialVariant> materialVariants = [
  (suffix: 'apple', matcFlags: ['-a', 'metal']),
  (suffix: 'android', matcFlags: ['-a', 'vulkan', '-a', 'opengl']),
  (suffix: 'desktop', matcFlags: ['-a', 'vulkan', '-a', 'opengl']),
  (suffix: 'opengl', matcFlags: ['-a', 'opengl']),
  (suffix: 'vulkan', matcFlags: ['-a', 'vulkan']),
  (suffix: 'webgpu', matcFlags: ['-a', 'webgpu']),
  (suffix: 'web_webgl', matcFlags: ['-a', 'opengl']),
  (suffix: 'web_combined', matcFlags: ['-a', 'opengl', '-a', 'webgpu']),
];

/// Embedded material sources (`materials/<name>.mat` inside the package),
/// in `materials/build.sh` order. `gizmo` is separate: its resgen prefix
/// stays `gizmo` (so symbols are GIZMO_*) but files are renamed
/// `gizmo_material_*` to avoid a case-insensitive .obj collision with
/// scene/Gizmo.cpp on Windows.
const List<String> embeddedMaterials = [
  'image',
  'unlit_fixed_size',
  'grid',
  'linear_depth',
  'silhouette',
  'edge_outline',
  'wireframe',
  'translation_axis',
  'bone_overlay',
  'capture_uv',
];

const String gizmoMaterialName = 'gizmo';
const String gizmoFileStem = 'gizmo_material';

/// Thrown for unrecoverable material-tool problems: unsupported hosts, bad
/// downloads, or a matc that cannot compile WebGPU materials. The build hook
/// catches this and falls back to the committed artifacts (with a warning),
/// so the message must be actionable on its own.
class MaterialToolsError implements Exception {
  MaterialToolsError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when matc or resgen fails during generation.
class MaterialGenerationError implements Exception {
  MaterialGenerationError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Which R2 artifact to fetch for the HOST machine (not the build target).
typedef MaterialToolsSpec = ({
  /// R2 platform token: linux, linux-arm64, macos or windows.
  String hostPlatform,

  /// Zip name on R2, e.g. filament-v1.77.2-linux-release.zip.
  String zipName,

  /// Full R2 URL of the zip.
  String url,

  /// Per-user cache dir name, e.g. filament-v1.77.2-webgpu-linux. The
  /// -webgpu marker distinguishes these from any future non-WebGPU matc
  /// cache (same idea as scripts/regenerate-materials.sh).
  String cacheDirName,

  /// '.exe' on Windows, '' elsewhere.
  String exeSuffix,
});

/// Resolves the host tool spec for [version] (the pinned Filament version
/// tag, e.g. v1.77.2). [hostOS] is `Platform.operatingSystem` ('linux',
/// 'macos', 'windows'); [hostArch] is 'x64' or 'arm64' style (only Linux
/// distinguishes — its arm64 hosts need their own artifact).
///
/// Throws [MaterialToolsError] for hosts or architectures with no R2
/// artifact (iOS/Android can never be build hosts here).
MaterialToolsSpec resolveMaterialToolsSpec({
  required String version,
  required String hostOS,
  required String hostArch,
}) {
  final os = hostOS.toLowerCase();
  final arch = hostArch.toLowerCase();
  late String platform;
  var exeSuffix = '';
  switch (os) {
    case 'linux':
      if (arch == 'arm64' || arch == 'aarch64') {
        platform = 'linux-arm64';
      } else if (arch == 'x64' || arch == 'x86_64' || arch == 'amd64') {
        platform = 'linux';
      } else {
        throw MaterialToolsError(
          'Cannot compile materials on Linux/$hostArch: no Filament tools '
          'artifact exists for that architecture.',
        );
      }
    case 'macos':
      platform = 'macos';
    case 'windows':
      platform = 'windows';
      exeSuffix = '.exe';
    default:
      throw MaterialToolsError(
        'Cannot compile materials on $hostOS: material compilation in the '
        'build hook is supported on Linux, macOS and Windows hosts only.',
      );
  }
  return (
    hostPlatform: platform,
    zipName: 'filament-$version-$platform-release.zip',
    url: '$materialToolsR2BaseUrl/filament-$version-$platform-release.zip',
    cacheDirName: 'filament-$version-webgpu-$platform',
    exeSuffix: exeSuffix,
  );
}

/// Per-user cache root for matc/resgen, mirroring
/// scripts/regenerate-materials.sh: `$XDG_CACHE_HOME` or `$HOME/.cache`,
/// plus `/thermion/filament-tools`. Returns null when neither variable is
/// set; callers then fall back to a cache under the package's `.dart_tool`.
/// The build hook runs with a curated PATH/HOME-only environment, so HOME
/// is expected but XDG_CACHE_HOME usually is not.
String? defaultMaterialToolsCacheRoot([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  String? base;
  final xdg = env['XDG_CACHE_HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    base = xdg;
  } else {
    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      base = p.join(home, '.cache');
    }
  }
  return base == null ? null : p.join(base, 'thermion', 'filament-tools');
}

/// Detects the host architecture in 'x64'/'arm64' terms. dart:io has no
/// direct API (Platform.executableArchitecture is not available on the
/// SDKs this package supports), so ask the OS: uname -m where it exists,
/// PROCESSOR_ARCHITECTURE on Windows. Returns null when unknown.
Future<String?> detectHostArchitecture() async {
  if (Platform.isWindows) {
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
    if (arch.contains('ARM64')) return 'arm64';
    if (arch.contains('AMD64') || arch.contains('x64')) return 'x64';
    return null;
  }
  try {
    final result = await Process.run('uname', ['-m']);
    if (result.exitCode == 0) {
      final machine = (result.stdout as String).trim();
      if (machine == 'aarch64' || machine == 'arm64') return 'arm64';
      if (machine == 'x86_64' || machine == 'amd64') return 'x64';
      return machine;
    }
  } catch (_) {
    // fall through
  }
  return null;
}

/// SHA-256 over everything that can change the generated artifacts: the
/// pipeline version, the Filament version (matc behavior), the host tool
/// platform, the variant flag table, the material list, and the content
/// hash of every input file under `materials/` (sorted by relative path so
/// the result is stable across file system orderings).
String computeMaterialsFingerprint({
  required String version,
  required String hostPlatform,
  required Iterable<MapEntry<String, String>> sourceHashes,
}) {
  final buffer = StringBuffer();
  buffer.writeln('pipeline=$materialPipelineVersion');
  buffer.writeln('filament=$version');
  buffer.writeln('tools=$hostPlatform');
  buffer.writeln(
    'variants=${materialVariants.map((v) => '${v.suffix}:${v.matcFlags.join(',')}').join('|')}',
  );
  buffer.writeln('materials=${embeddedMaterials.join(',')},$gizmoMaterialName');
  final entries = sourceHashes.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in entries) {
    buffer.writeln('${entry.key}=${entry.value}');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

/// Content hashes (relative path -> sha256 hex) of every material input
/// under [sourceDir]: `.mat` sources and the headers they `#include`
/// (materials/shared.h). `.filamat` intermediates from a local
/// `make materials` run are deliberately excluded — they are outputs.
///
/// Returns an empty map when the directory is missing; callers decide
/// whether that is fatal.
Map<String, String> hashMaterialSources(Directory sourceDir) {
  if (!sourceDir.existsSync()) return const {};
  final hashes = <String, String>{};
  for (final entity in sourceDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final ext = p.extension(entity.path).toLowerCase();
    if (ext != '.mat' && ext != '.h') continue;
    hashes[p.relative(entity.path, from: sourceDir.path)] =
        sha256.convert(entity.readAsBytesSync()).toString();
  }
  return hashes;
}

/// The generated-artifacts cache dir for a package:
/// `<packageRoot>/.dart_tool/thermion_dart/materials/<version>` — versioned,
/// so a Filament bump never reuses a stale set. The actual C sources live in
/// its `material/` subdirectory, layout-identical to
/// `native/include/material/` so it can be prepended to the include path.
Directory generatedMaterialsRoot(Directory packageRoot, String version) => Directory(
  p.join(packageRoot.path, '.dart_tool', 'thermion_dart', 'materials', version),
);

/// Reads the fingerprint from a manifest, or null when the manifest is
/// missing/corrupt (treated as a cache miss).
String? manifestFingerprint(File manifest) {
  if (!manifest.existsSync()) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(manifest.readAsStringSync());
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  if (decoded['schema'] != materialPipelineVersion) return null;
  final fingerprint = decoded['fingerprint'];
  return fingerprint is String ? fingerprint : null;
}

/// Writes the manifest recording [fingerprint] and the sha256 of the tools
/// that produced the artifacts (provenance for debugging cache issues).
void writeMaterialManifest(File manifest, {required String fingerprint, required Map<String, String> toolHashes}) {
  manifest.createSync(recursive: true);
  manifest.writeAsStringSync(
    jsonEncode({
      'schema': materialPipelineVersion,
      'fingerprint': fingerprint,
      'tools': toolHashes,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    }),
    flush: true,
  );
}

/// Extracts only `bin/*` entries from [archive] into [destination] and
/// returns the relative paths written. The release zip is dominated by
/// static libraries and headers that matc/resgen never need (the same
/// reason scripts/regenerate-materials.sh unpacks only `bin/*`).
List<String> extractToolBinaries(Archive archive, Directory destination) {
  final written = <String>[];
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final name = entry.name;
    final rel = name.startsWith('./') ? name.substring(2) : name;
    if (rel != 'bin' && !rel.startsWith('bin/')) continue;
    final file = File(p.join(destination.path, rel));
    file.createSync(recursive: true);
    file.writeAsBytesSync(entry.content as List<int>);
    written.add(rel);
  }
  return written;
}

/// Minimal material used to smoke-test matc: a matc built without
/// FILAMENT_SUPPORTS_WEBGPU (like the official Filament release binaries)
/// fails to compile it, so a bad or wrong-version tool cache is detected
/// before it fails on every real material.
const String smokeMaterialSource = 'material {\n    name : smoke_webgpu,\n    shadingModel : unlit\n}\n';

/// Result of running a tool. Kept as a plain record so tests can fake it.
typedef ToolRunResult = ({int exitCode, String stdout, String stderr});

/// Runs [executable] with [args]. Injectable for tests.
typedef ToolProcess = Future<ToolRunResult> Function(String executable, List<String> args);

/// Injectable downloader: fetches [url] into [destination]. The build hook
/// passes its retrying implementation; tests write local fixture zips.
typedef UrlDownloader = Future<void> Function(Uri url, File destination);

Future<ToolRunResult> _defaultRunProcess(String executable, List<String> args) async {
  final result = await Process.run(executable, args);
  return (exitCode: result.exitCode, stdout: result.stdout.toString(), stderr: result.stderr.toString());
}

Future<void> _defaultDownload(Uri url, File destination) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(url);
    final response = await request.close().timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw MaterialToolsError('HTTP ${response.statusCode} downloading $url');
    }
    await response.pipe(destination.openWrite());
  } finally {
    client.close();
  }
  if (!destination.existsSync() || destination.lengthSync() == 0) {
    throw MaterialToolsError('Downloaded file is empty: ${destination.path}');
  }
}

/// Compiles [smokeMaterialSource] with `-a webgpu`. Returns true only when
/// matc exits 0 AND produced the output file.
Future<bool> smokeTestMatc(File matc, {ToolProcess? runProcess, Directory? workDir}) async {
  final dir = workDir ?? Directory.systemTemp.createTempSync('thermion_matc_smoke_');
  try {
    final smokeMat = File(p.join(dir.path, 'smoke.mat'));
    final smokeOut = File(p.join(dir.path, 'smoke.filamat'));
    smokeMat.writeAsStringSync(smokeMaterialSource, flush: true);
    if (smokeOut.existsSync()) smokeOut.deleteSync();
    final result = await (runProcess ?? _defaultRunProcess)(matc.path, [
      '-a', 'webgpu',
      '-o', smokeOut.path,
      smokeMat.path,
    ]);
    return result.exitCode == 0 && smokeOut.existsSync();
  } finally {
    if (workDir == null) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

/// The resolved matc/resgen pair, and whether this call had to download it.
typedef MaterialTools = ({File matc, File resgen, bool downloaded});

/// Makes sure a WebGPU-capable matc/resgen pair for [spec] exists under
/// [cacheRoot], downloading it from R2 when needed.
///
/// Mirrors scripts/regenerate-materials.sh: the cache is trusted only after
/// matc passes the `-a webgpu` smoke test; a failing (or missing) cache is
/// deleted and re-downloaded once, and a matc that still cannot compile
/// WebGPU materials afterwards throws [MaterialToolsError].
Future<MaterialTools> ensureMaterialTools({
  required MaterialToolsSpec spec,
  required Directory cacheRoot,
  UrlDownloader? download,
  ToolProcess? runProcess,
  void Function(String message)? onLog,
}) async {
  final log = onLog ?? (_) {};
  final fetch = download ?? _defaultDownload;
  final toolsDir = Directory(p.join(cacheRoot.path, spec.cacheDirName));
  final matc = File(p.join(toolsDir.path, 'bin', 'matc${spec.exeSuffix}'));
  final resgen = File(p.join(toolsDir.path, 'bin', 'resgen${spec.exeSuffix}'));

  Future<bool> toolsOk() async {
    if (!matc.existsSync() || !resgen.existsSync()) return false;
    return smokeTestMatc(matc, runProcess: runProcess);
  }

  if (await toolsOk()) {
    log('Using cached WebGPU-capable matc/resgen from ${toolsDir.path}');
    return (matc: matc, resgen: resgen, downloaded: false);
  }

  log('Downloading Filament tools (matc, resgen) from ${spec.url}');
  if (toolsDir.existsSync()) {
    toolsDir.deleteSync(recursive: true);
  }
  cacheRoot.createSync(recursive: true);
  final zipFile = File(p.join(cacheRoot.path, spec.zipName));
  try {
    await fetch(Uri.parse(spec.url), zipFile);
    final extracted = extractToolBinaries(ZipDecoder().decodeBytes(await zipFile.readAsBytes()), toolsDir);
    log('Extracted ${extracted.length} tool files into ${toolsDir.path}');
  } finally {
    if (zipFile.existsSync()) {
      zipFile.deleteSync();
    }
  }
  if (!matc.existsSync() || !resgen.existsSync()) {
    throw MaterialToolsError(
      'The Filament artifact ${spec.url} does not contain bin/matc and '
      'bin/resgen for this host (${spec.hostPlatform}).\n'
      'Material compilation needs a Build Filament workflow run for the '
      'pinned Filament version that ships the shader tools. Until then, set '
      'compile_materials: false under hooks.user_defines.thermion_dart in '
      'your pubspec.yaml to use the committed material artifacts.',
    );
  }
  await _makeExecutable([matc, resgen]);
  if (!await toolsOk()) {
    // A stale tools dir must not survive a failed smoke test.
    toolsDir.deleteSync(recursive: true);
    throw MaterialToolsError(
      'matc from ${spec.url} does not support -a webgpu (smoke test failed '
      'after a fresh download).\n'
      'The R2 artifact was built without FILAMENT_SUPPORTS_WEBGPU; re-run '
      'the Build Filament workflow for the pinned Filament version, or set '
      'compile_materials: false under hooks.user_defines.thermion_dart in '
      'your pubspec.yaml to use the committed material artifacts.',
    );
  }
  return (matc: matc, resgen: resgen, downloaded: true);
}

/// The archive package does not preserve the executable bit, and zip entries
/// extracted on POSIX cannot run without it.
Future<void> _makeExecutable(List<File> files) async {
  if (Platform.isWindows) return;
  for (final file in files) {
    if (!file.existsSync()) continue;
    final result = await Process.run('chmod', ['+x', file.path]);
    if (result.exitCode != 0) {
      throw MaterialToolsError('Could not make ${file.path} executable: ${result.stderr}');
    }
  }
}

/// Result of [ensureGeneratedMaterials]: the directory (layout-identical to
/// `native/include/material/`) to compile against, and whether this call
/// regenerated it.
typedef GeneratedMaterials = ({Directory materialDir, bool regenerated});

/// End-to-end entry point used by the build hook.
///
/// Returns the cached generated material directory when the fingerprint of
/// (`filament.version` + `materials/` contents + pipeline) matches the
/// manifest — no download, no matc run. Otherwise fetches the host tools
/// via [ensureMaterialTools] and regenerates every variant.
///
/// Throws [MaterialToolsError]/[MaterialGenerationError] on failure; the
/// caller decides whether to fall back to the committed artifacts.
Future<GeneratedMaterials> ensureGeneratedMaterials({
  required Directory packageRoot,
  required String version,
  required String hostOS,
  required String hostArch,
  String? toolsCacheRoot,
  UrlDownloader? download,
  ToolProcess? runProcess,
  void Function(String message)? onLog,
}) async {
  final log = onLog ?? (_) {};
  final spec = resolveMaterialToolsSpec(version: version, hostOS: hostOS, hostArch: hostArch);

  final sourceDir = Directory(p.join(packageRoot.path, 'materials'));
  final sourceHashes = hashMaterialSources(sourceDir);
  if (sourceHashes.isEmpty) {
    throw MaterialToolsError(
      'No .mat sources found under ${sourceDir.path}; cannot compile '
      'materials.',
    );
  }
  final fingerprint = computeMaterialsFingerprint(
    version: version,
    hostPlatform: spec.hostPlatform,
    sourceHashes: sourceHashes.entries,
  );

  final outRoot = generatedMaterialsRoot(packageRoot, version);
  final materialDir = Directory(p.join(outRoot.path, 'material'));
  final manifest = File(p.join(outRoot.path, materialManifestName));
  if (generatedMaterialsComplete(materialDir) && manifestFingerprint(manifest) == fingerprint) {
    log('Materials up to date (fingerprint ${fingerprint.substring(0, 12)}); skipping recompilation');
    return (materialDir: materialDir, regenerated: false);
  }

  final cacheRoot = toolsCacheRoot ?? defaultMaterialToolsCacheRoot() ?? p.join(
    packageRoot.path, '.dart_tool', 'thermion_dart', 'filament-tools',
  );
  final tools = await ensureMaterialTools(
    spec: spec,
    cacheRoot: Directory(cacheRoot),
    download: download,
    runProcess: runProcess,
    onLog: onLog,
  );

  await generateEmbeddedMaterials(
    sourceDir: sourceDir,
    outputRoot: outRoot,
    matc: tools.matc,
    resgen: tools.resgen,
    fingerprint: fingerprint,
    runProcess: runProcess,
    onLog: onLog,
  );
  return (materialDir: materialDir, regenerated: true);
}

/// Whether [dir] holds every expected generated `.c` file (one per material
/// per variant). The manifest alone is not trusted: a partially deleted
/// cache must regenerate, not silently satisfy the skip.
bool generatedMaterialsComplete(Directory dir) {
  if (!dir.existsSync()) return false;
  for (final name in [...embeddedMaterials, gizmoMaterialName]) {
    final stem = name == gizmoMaterialName ? gizmoFileStem : name;
    for (final variant in materialVariants) {
      if (!File(p.join(dir.path, '${stem}_${variant.suffix}.c')).existsSync()) {
        return false;
      }
    }
  }
  return true;
}

/// Regenerates every material variant into `<outputRoot>/material` — a
/// faithful port of the main loop of `materials/build.sh` (see that script
/// for the variant table rationale). All variants share one resgen symbol
/// prefix per material, so the C symbols are identical across variants and
/// exactly one `.c` gets compiled per target, selected by the
/// `THERMION_MATERIAL_*` defines (resolveMaterialBackend).
///
/// Writes into a private staging directory first and swaps it into place
/// only once every variant compiled and the manifest was written, so an
/// interrupted run can never leave a half-written artifact set where the
/// build can find it.
Future<void> generateEmbeddedMaterials({
  required Directory sourceDir,
  required Directory outputRoot,
  required File matc,
  required File resgen,
  required String fingerprint,
  ToolProcess? runProcess,
  void Function(String message)? onLog,
}) async {
  final log = onLog ?? (_) {};
  final run = runProcess ?? _defaultRunProcess;
  outputRoot.createSync(recursive: true);
  // Stale staging dirs are leftovers of interrupted runs.
  for (final entity in outputRoot.listSync()) {
    if (entity is Directory && p.basename(entity.path).startsWith('material.staging-')) {
      entity.deleteSync(recursive: true);
    }
  }
  final staging = Directory(p.join(outputRoot.path, 'material.staging-${pid}'));
  staging.createSync(recursive: true);
  final materialOut = Directory(p.join(staging.path, 'material'))..createSync();
  final intermediates = Directory(p.join(staging.path, 'intermediates'))..createSync();

  try {
    for (final name in embeddedMaterials) {
      log('Compiling material $name');
      await _buildMaterial(
        name: name,
        fileStem: name,
        sourceDir: sourceDir,
        materialOut: materialOut,
        intermediates: intermediates,
        matc: matc,
        resgen: resgen,
        run: run,
        log: log,
      );
    }
    log('Compiling material $gizmoMaterialName (renamed to ${gizmoFileStem}_)');
    await _buildMaterial(
      name: gizmoMaterialName,
      fileStem: gizmoFileStem,
      sourceDir: sourceDir,
      materialOut: materialOut,
      intermediates: intermediates,
      matc: matc,
      resgen: resgen,
      run: run,
      log: log,
    );

    final finalDir = Directory(p.join(outputRoot.path, 'material'));
    if (finalDir.existsSync()) {
      finalDir.deleteSync(recursive: true);
    }
    materialOut.renameSync(finalDir.path);
    // The manifest is the gate: written last, next to the artifacts, so a
    // crash before this point leaves an untrusted (regenerated-next-run) set.
    writeMaterialManifest(
      File(p.join(outputRoot.path, materialManifestName)),
      fingerprint: fingerprint,
      toolHashes: {
        'matc': sha256.convert(await matc.readAsBytes()).toString(),
        'resgen': sha256.convert(await resgen.readAsBytes()).toString(),
      },
    );
    log('Wrote ${finalDir.path} (fingerprint ${fingerprint.substring(0, 12)})');
  } finally {
    if (staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
  }
}

Future<void> _buildMaterial({
  required String name,
  required String fileStem,
  required Directory sourceDir,
  required Directory materialOut,
  required Directory intermediates,
  required File matc,
  required File resgen,
  required ToolProcess run,
  required void Function(String message) log,
}) async {
  final matFile = File(p.join(sourceDir.path, '$name.mat'));
  if (!matFile.existsSync()) {
    throw MaterialGenerationError('Material source not found: ${matFile.path}');
  }
  for (final variant in materialVariants) {
    log('  ${variant.suffix}: matc ${variant.matcFlags.join(' ')}');
    await _buildVariant(
      name: name,
      fileStem: fileStem,
      variant: variant,
      matFile: matFile,
      materialOut: materialOut,
      intermediates: intermediates,
      matc: matc,
      resgen: resgen,
      run: run,
    );
  }
  File(p.join(materialOut.path, '$name.h')).writeAsStringSync(forwardingHeaderSource(name: name, fileStem: fileStem));
}

/// Compiles one material/variant pair and rewrites the resgen output the
/// same way `materials/build.sh` does (see build_variant there): rename to
/// the suffixed files, point the `.c` at the suffixed header, give the
/// header a variant-specific guard plus `__cplusplus` extern guards.
Future<void> _buildVariant({
  required String name,
  required String fileStem,
  required MaterialVariant variant,
  required File matFile,
  required Directory materialOut,
  required Directory intermediates,
  required File matc,
  required File resgen,
  required ToolProcess run,
}) async {
  final filamat = File(p.join(intermediates.path, '$name.filamat'));
  if (filamat.existsSync()) filamat.deleteSync();

  final matcResult = await run(matc.path, [...variant.matcFlags, '-o', filamat.path, matFile.path]);
  if (matcResult.exitCode != 0 || !filamat.existsSync()) {
    throw MaterialGenerationError(
      'matc failed for $name (${variant.suffix}):\n'
      '${matcResult.stderr.isNotEmpty ? matcResult.stderr : matcResult.stdout}',
    );
  }

  final resgenResult = await run(resgen.path, ['-c', '-p', name, '-x', '${materialOut.path}${Platform.pathSeparator}', filamat.path]);
  if (resgenResult.exitCode != 0) {
    throw MaterialGenerationError(
      'resgen failed for $name (${variant.suffix}):\n'
      '${resgenResult.stderr.isNotEmpty ? resgenResult.stderr : resgenResult.stdout}',
    );
  }
  filamat.deleteSync();

  // Rename to the suffixed files.
  final variantC = File(p.join(materialOut.path, '${fileStem}_${variant.suffix}.c'));
  final variantH = File(p.join(materialOut.path, '${fileStem}_${variant.suffix}.h'));
  File(p.join(materialOut.path, '$name.c')).renameSync(variantC.path);
  File(p.join(materialOut.path, '$name.h')).renameSync(variantH.path);

  // Fix the include in the .c, then prepend it (build.sh does both; resgen
  // currently emits no self-include, so the replacement is a no-op safety).
  final upperStem = fileStem.toUpperCase();
  final upperSuffix = variant.suffix.toUpperCase();
  final cSource = variantC.readAsStringSync().replaceAll(
    '#include "$name.h"',
    '#include "${fileStem}_${variant.suffix}.h"',
  );
  variantC.writeAsStringSync('#include "${fileStem}_${variant.suffix}.h"\n$cSource');

  // Variant-specific header guard + __cplusplus extern "C" guards.
  var hSource = variantH.readAsStringSync();
  hSource = hSource.replaceAll('${name.toUpperCase()}_H_', '${upperStem}_${upperSuffix}_H_');
  hSource = hSource.replaceFirst('extern "C" {', '#ifdef __cplusplus\nextern "C" {\n#endif');
  hSource = hSource.replaceAll('\n}\n', '\n#ifdef __cplusplus\n}\n#endif\n');
  variantH.writeAsStringSync(hSource);
}

/// The forwarding header that dispatches to the right variant via the
/// `THERMION_MATERIAL_*` defines — byte-identical to what
/// `materials/build.sh` create_forwarding_header emits (see
/// native/include/material/image.h). [name] is the material name (also the
/// header guard prefix and the header file name); [fileStem] is the variant
/// file stem, which only differs for gizmo (gizmo_material).
String forwardingHeaderSource({required String name, required String fileStem}) {
  final upper = name.toUpperCase();
  final buffer = StringBuffer();
  buffer.writeln('#ifndef ${upper}_H_');
  buffer.writeln('#define ${upper}_H_');
  buffer.writeln();
  for (var i = 0; i < materialVariants.length; i++) {
    final variant = materialVariants[i];
    final keyword = i == 0 ? '#if' : '#elif';
    buffer.writeln('$keyword defined(THERMION_MATERIAL_${variant.suffix.toUpperCase()})');
    buffer.writeln('#include "${fileStem}_${variant.suffix}.h"');
  }
  buffer.writeln('#else');
  buffer.writeln(
    '#error "No material backend variant selected. Define one of: '
    '${materialVariants.map((v) => 'THERMION_MATERIAL_${v.suffix.toUpperCase()}').join(', ')}"',
  );
  buffer.writeln('#endif');
  buffer.writeln();
  buffer.writeln('#endif');
  return buffer.toString();
}
