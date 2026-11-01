/// Opt-in host-side compilation of USER materials via matc/resgen.
///
/// A downstream app points thermion at its own `.mat` files with the
/// `material_compilation` user define:
///
/// ```yaml
/// hooks:
///   user_defines:
///     thermion_dart:
///       material_compilation:
///         inputs: [materials/skin.mat, materials/eye]
///         output: build/materials
///         backends: all   # all (default) | native | web | explicit -a list
///         resgen: false   # also emit .c/.h per material
/// ```
///
/// The hook then expands the inputs to `.mat` files, downloads the
/// WebGPU-capable `matc`/`resgen` pair matching the Filament version pinned
/// in `filament.version` from R2 (for the HOST platform, not the target)
/// into a per-user cache, and compiles each material into ONE blended
/// `.filamat` package (every requested backend in a single blob) under the
/// configured output directory. A `<output>/.thermion-materials.json`
/// manifest records the `matcId` (Filament tag + thermion_dart version +
/// host platform/arch), the sha256 of the downloaded matc binary and the
/// hash of every input: when nothing changed, later builds skip the
/// download and the compilation; when the `matcId` (or the matc binary's
/// hash) changes — e.g. a Filament or thermion_dart bump ships a new matc —
/// EVERY material is recompiled even if no `.mat` changed.
///
/// User materials are never compiled into a native library: the runtime
/// loads them from bytes (`FilamentApp.createMaterial(Uint8List data)`), so
/// the build product is a `.filamat` file on disk (plus optional `.c`/`.h`
/// via `resgen`).
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

/// Bumped whenever this pipeline changes shape (backend presets, manifest
/// schema, matcId scheme). Folded into the matcId so an old output directory
/// can never satisfy a new pipeline.
const int materialPipelineVersion = 2;

/// Name of the manifest written into the output directory (written LAST —
/// it is the gate that makes repeat builds fast).
const String materialManifestName = '.thermion-materials.json';

/// matc architecture flags for `backends: all` — one blended package per
/// material carrying every backend, so a single stable filename works on
/// every platform and runtime loading stays trivial.
const List<String> allMaterialBackends = ['metal', 'vulkan', 'opengl', 'webgpu'];

/// Every `-a` value matc accepts for the platforms Thermion supports.
const List<String> knownMaterialBackends = ['metal', 'vulkan', 'opengl', 'webgpu'];

/// Thrown for unrecoverable material-tool problems: bad configuration,
/// unsupported hosts, failed downloads. Messages are actionable on their
/// own; the build hook lets them fail the build (never a silent skip).
class MaterialToolsError implements Exception {
  MaterialToolsError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when matc or resgen fails during compilation.
class MaterialGenerationError implements Exception {
  MaterialGenerationError(this.message);
  final String message;

  @override
  String toString() => message;
}

//
// Configuration
//

/// The resolved `material_compilation` user define.
class MaterialCompilationConfig {
  MaterialCompilationConfig({
    required this.inputs,
    required this.output,
    required this.backends,
    required this.resgen,
    this.resgenPrefixes = const {},
  });

  /// Files, directories or globs, relative to the consuming app root.
  final List<String> inputs;

  /// Output directory, relative to the consuming app root (created if
  /// missing). Absolute paths are used as-is.
  final String output;

  /// matc `-a` flags blended into every package (see [resolveBackends]).
  final List<String> backends;

  /// Also convert each `.filamat` to C (`resgen -c`).
  final bool resgen;

  /// Optional `resgen_prefixes` overrides: material name (file stem) ->
  /// symbol prefix. Unlisted materials use their sanitised name.
  final Map<String, String> resgenPrefixes;

  /// True when [backends] is the full `all` preset.
  bool get isAllBackends => listEquals(backends, allMaterialBackends);
}

bool listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Normalizes the `backends` key of `material_compilation`.
///
///   - null            -> [allMaterialBackends] (the default)
///   - "all"           -> [allMaterialBackends]
///   - "native"        -> metal + vulkan + opengl (no WebGPU)
///   - "web"           -> opengl + webgpu (what a browser can load)
///   - a list of names -> used as-is (validated), e.g. [vulkan]
///
/// Unknown values throw [MaterialToolsError] naming the bad value.
List<String> resolveBackends(Object? raw) {
  if (raw == null) return List.of(allMaterialBackends);
  if (raw is String) {
    switch (raw.trim().toLowerCase()) {
      case 'all':
        return List.of(allMaterialBackends);
      case 'native':
        return ['metal', 'vulkan', 'opengl'];
      case 'web':
        return ['opengl', 'webgpu'];
      default:
        throw MaterialToolsError(
          "Unknown backends preset '$raw' in material_compilation. "
          'Use all (default), native, web, or an explicit list such as '
          '[vulkan, opengl].',
        );
    }
  }
  if (raw is List) {
    final backends = <String>[];
    for (final value in raw) {
      final name = (value is String ? value : value.toString()).trim().toLowerCase();
      if (!knownMaterialBackends.contains(name)) {
        throw MaterialToolsError(
          "Unknown backend '$value' in material_compilation.backends. "
          'Valid backends: ${knownMaterialBackends.join(', ')}.',
        );
      }
      if (!backends.contains(name)) backends.add(name);
    }
    if (backends.isEmpty) {
      throw MaterialToolsError('material_compilation.backends is an empty list; there would be nothing to compile.');
    }
    return backends;
  }
  throw MaterialToolsError(
    'material_compilation.backends must be a string preset (all/native/web) '
    'or a list of backend names, but got ${raw.runtimeType}.',
  );
}

/// Parses the raw `material_compilation` user define into a config.
///
/// Returns null when [raw] is null (the feature is opt-in: absent means the
/// hook does nothing new). Any present-but-invalid value throws
/// [MaterialToolsError] with an actionable message — a misconfigured opt-in
/// feature must fail the build, not silently no-op.
MaterialCompilationConfig? parseMaterialCompilationConfig(Object? raw, {void Function(String message)? onLog}) {
  if (raw == null) return null;
  final log = onLog ?? (_) {};
  if (raw is! Map) {
    throw MaterialToolsError(
      'material_compilation must be a map (inputs, output, backends, '
      'resgen), but got ${raw.runtimeType}. See the Thermion materials docs.',
    );
  }
  final map = Map<String, dynamic>.from(raw);

  const knownKeys = {'inputs', 'output', 'backends', 'resgen', 'resgen_prefixes'};
  for (final key in map.keys) {
    if (!knownKeys.contains(key)) {
      log(
        'Unknown key "$key" in material_compilation (ignored). '
        'Known keys: ${knownKeys.join(', ')}',
      );
    }
  }

  final rawInputs = map['inputs'];
  if (rawInputs is! List || rawInputs.isEmpty) {
    throw MaterialToolsError(
      'material_compilation.inputs must be a non-empty list of .mat files, '
      'directories or globs relative to your app root.',
    );
  }
  final inputs = <String>[];
  for (final value in rawInputs) {
    if (value is! String || value.trim().isEmpty) {
      throw MaterialToolsError(
        'material_compilation.inputs entries must be non-empty strings '
        '(files, directories or globs), but got: $value.',
      );
    }
    inputs.add(value.trim());
  }

  final output = map['output'];
  if (output is! String || output.trim().isEmpty) {
    throw MaterialToolsError(
      'material_compilation.output must be a non-empty directory path '
      'relative to your app root (created if missing).',
    );
  }

  final resgenRaw = map['resgen'];
  if (resgenRaw != null && resgenRaw is! bool) {
    throw MaterialToolsError('material_compilation.resgen must be true or false, but got ${resgenRaw.runtimeType}.');
  }

  final prefixesRaw = map['resgen_prefixes'];
  final prefixes = <String, String>{};
  if (prefixesRaw != null) {
    if (prefixesRaw is! Map) {
      throw MaterialToolsError(
        'material_compilation.resgen_prefixes must be a map of material '
        'name to resgen prefix, but got ${prefixesRaw.runtimeType}.',
      );
    }
    prefixesRaw.forEach((name, prefix) {
      if (prefix is! String || prefix.trim().isEmpty) {
        throw MaterialToolsError('material_compilation.resgen_prefixes["$name"] must be a non-empty prefix string.');
      }
      prefixes['$name'] = prefix.trim();
    });
  }

  return MaterialCompilationConfig(
    inputs: inputs,
    output: output.trim(),
    backends: resolveBackends(map['backends']),
    resgen: resgenRaw == true,
    resgenPrefixes: prefixes,
  );
}

//
// Input resolution
//

/// True when an input string is a glob rather than a literal path.
bool _isGlob(String input) => input.contains('*') || input.contains('?') || input.contains('[');

/// Expands [config.inputs] against [appRoot] into a sorted, deduplicated
/// list of `.mat` files.
///
///   - an existing file   -> must have a `.mat` extension
///   - an existing dir    -> every `.mat` under it, recursively
///   - a glob (*/?/[)    -> matched against files under the static prefix
///                           of the pattern, recursively; only `.mat`
///                           matches are kept
///
/// Anything else throws [MaterialToolsError] naming the input — a typo must
/// fail the build, not silently compile nothing.
List<File> expandMaterialInputs({required Directory appRoot, required List<String> inputs}) {
  final files = <String>{};
  void addFile(File file) {
    if (p.extension(file.path).toLowerCase() == '.mat') files.add(file.path);
  }

  for (final input in inputs) {
    final normalized = input.replaceAll('/', p.separator);
    final isGlob = _isGlob(input);
    final absolute = p.isAbsolute(normalized) ? normalized : p.join(appRoot.path, normalized);

    if (isGlob) {
      for (final match in _globMatches(absolute)) {
        addFile(File(match));
      }
      continue;
    }

    if (FileSystemEntity.isDirectorySync(absolute)) {
      for (final entity in Directory(absolute).listSync(recursive: true, followLinks: false)) {
        if (entity is File) addFile(entity);
      }
      continue;
    }

    if (FileSystemEntity.isFileSync(absolute)) {
      if (p.extension(absolute).toLowerCase() != '.mat') {
        throw MaterialToolsError(
          'material_compilation input "$input" is not a .mat file '
          '(${absolute}). matc only compiles .mat sources.',
        );
      }
      addFile(File(absolute));
      continue;
    }

    throw MaterialToolsError(
      'material_compilation input "$input" does not exist (resolved to '
      '$absolute under ${appRoot.path}).',
    );
  }

  final expanded = files.toList()..sort();
  if (expanded.isEmpty) {
    throw MaterialToolsError(
      'material_compilation.inputs resolved to no .mat files '
      '(${inputs.join(', ')}).',
    );
  }
  return expanded.map(File.new).toList();
}

/// Matches an absolute glob pattern ([pattern]) against every file under
/// its deepest static directory. Supports `*` (within one segment), `**`
/// (across segments) and `?`.
Iterable<String> _globMatches(String pattern) {
  final segments = p.split(pattern);
  var staticPrefix = <String>[];
  for (final segment in segments) {
    if (_isGlob(segment)) break;
    staticPrefix.add(segment);
  }
  final root = p.joinAll(staticPrefix);
  if (!FileSystemEntity.isDirectorySync(root)) {
    throw MaterialToolsError(
      'material_compilation glob "$pattern" has no existing directory '
      'prefix ($root).',
    );
  }
  final matcher = _globRegExp(pattern, fromDir: root);
  final matches = <String>[];
  for (final entity in Directory(root).listSync(recursive: true, followLinks: false)) {
    if (entity is File && matcher.hasMatch(p.relative(entity.path, from: root))) {
      matches.add(entity.path);
    }
  }
  return matches;
}

/// Builds a RegExp for the part of [pattern] below [fromDir].
RegExp _globRegExp(String pattern, {required String fromDir}) {
  final relative = p.relative(pattern, from: fromDir);
  final buffer = StringBuffer('^');
  var i = 0;
  while (i < relative.length) {
    final char = relative[i];
    if (char == '*') {
      if (i + 1 < relative.length && relative[i + 1] == '*') {
        buffer.write('.*');
        i += 2;
        // Tolerate a following separator (e.g. dir/**/x).
        if (i < relative.length && (relative[i] == '/' || relative[i] == p.separator)) i++;
        continue;
      }
      buffer.write('[^${p.separator}]*');
      i++;
      continue;
    }
    if (char == '?') {
      buffer.write('[^${p.separator}]');
      i++;
      continue;
    }
    buffer.write(RegExp.escape(char));
    i++;
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

/// The output stem for a `.mat` file: its basename without extension,
/// sanitised to a C-safe identifier ([A-Za-z0-9_]). Two inputs that
/// sanitise to the same stem would overwrite each other's outputs, so
/// [checkOutputStems] rejects them up front.
String materialOutputStem(File mat) {
  final stem = p.basenameWithoutExtension(mat.path);
  final sanitized = stem.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');
  if (sanitized.isEmpty || sanitized == '_') {
    throw MaterialToolsError('Cannot derive an output name from ${mat.path}.');
  }
  return sanitized;
}

/// Every output file name a material produces with [resgen] enabled:
/// `<stem>.filamat` plus `resgen -p <prefix>` outputs (`<prefix>.c`,
/// `<prefix>.h`, and whatever else resgen emits beside them).
List<String> expectedOutputNames(String stem, {required bool resgen, String? prefix}) {
  return [
    '$stem.filamat',
    if (resgen) ...['${prefix ?? stem}.c', '${prefix ?? stem}.h'],
  ];
}

/// Maps every input to its output stem, rejecting collisions.
Map<File, String> checkOutputStems(List<File> inputs) {
  final stems = <File, String>{};
  final byStem = <String, File>{};
  for (final input in inputs) {
    final stem = materialOutputStem(input);
    final existing = byStem[stem];
    if (existing != null && p.absolute(existing.path) != p.absolute(input.path)) {
      throw MaterialToolsError(
        'material_compilation inputs ${p.basename(existing.path)} and '
        '${p.basename(input.path)} both produce the output name "$stem". '
        'Rename one of them — outputs would overwrite each other.',
      );
    }
    byStem[stem] = input;
    stems[input] = stem;
  }
  return stems;
}

//
// matcId + manifest
//

/// Computes the `matcId`: the identity of the tool that must have produced
/// every blob in the output directory.
///
/// sha256 over the pipeline version, the pinned Filament tag, the
/// thermion_dart package version and the host platform/arch. Any change (a
/// Filament bump, a thermion_dart bump, building on another machine) forces
/// a full rebuild. The downloaded matc binary's own sha256 is recorded in
/// the manifest as `matcSha256` and ALSO forces a full rebuild when it
/// changes — it is deliberately NOT part of the matcId, because the binary
/// is not hashable before the first download (a null->known transition
/// would otherwise rebuild every project once for no reason).
String computeMatcId({
  required String filamentVersion,
  required String packageVersion,
  required String hostPlatform,
  required String hostArch,
}) {
  final buffer = StringBuffer()
    ..writeln('pipeline=$materialPipelineVersion')
    ..writeln('filament=$filamentVersion')
    ..writeln('package=$packageVersion')
    ..writeln('host=$hostPlatform/$hostArch');
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

/// First 12 chars of a hash-like id, tolerating short test values.
String _shortId(String id) => id.length <= 12 ? id : id.substring(0, 12);

/// The recorded state of an output directory.
class MaterialsManifest {
  MaterialsManifest({
    required this.matcId,
    required this.matcSha256,
    required this.backends,
    required this.resgen,
    required this.inputs,
  });

  final String matcId;
  final String? matcSha256;
  final List<String> backends;
  final bool resgen;

  /// input path (relative to the app root, as passed in) -> sha256, plus
  /// `"outputs/<input>": [file names]` entries recording what was written.
  final Map<String, String> inputs;
  final Map<String, List<String>> outputs = {};
}

/// Reads `<output>/.thermion-materials.json`; null when missing/corrupt
/// (treated as a full rebuild).
MaterialsManifest? readMaterialsManifest(File manifest) {
  if (!manifest.existsSync()) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(manifest.readAsStringSync());
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  if (decoded['schema'] != materialPipelineVersion) return null;
  final matcId = decoded['matcId'];
  if (matcId is! String) return null;
  final backends = decoded['backends'];
  if (backends is! List || backends.any((b) => b is! String)) return null;
  final inputs = decoded['inputs'];
  if (inputs is! Map<String, dynamic>) return null;
  final result = MaterialsManifest(
    matcId: matcId,
    matcSha256: decoded['matcSha256'] is String ? decoded['matcSha256'] as String : null,
    backends: List<String>.from(backends.cast<String>()),
    resgen: decoded['resgen'] == true,
    inputs: inputs.map((k, v) => MapEntry(k, v is String ? v : '')),
  );
  final outputs = decoded['outputs'];
  if (outputs is Map<String, dynamic>) {
    outputs.forEach((input, names) {
      if (names is List) result.outputs[input] = names.map((n) => '$n').toList();
    });
  }
  return result;
}

/// Serializes a manifest (also embeds the input -> outputs mapping used to
/// clean up after an input is removed from the config).
String encodeMaterialsManifest({
  required String matcId,
  required String? matcSha256,
  required List<String> backends,
  required bool resgen,
  required Map<String, String> inputs,
  required Map<String, List<String>> outputs,
}) {
  final orderedInputs = Map.fromEntries(inputs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  return const JsonEncoder.withIndent('  ').convert({
    'schema': materialPipelineVersion,
    'matcId': matcId,
    if (matcSha256 != null) 'matcSha256': matcSha256,
    'backends': backends,
    'resgen': resgen,
    'inputs': orderedInputs,
    'outputs': outputs,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
  });
}

//
// Host tools (download / cache / smoke test)
//

/// Which R2 artifact to fetch for the HOST machine (not the build target).
typedef MaterialToolsSpec = ({
  /// The pinned Filament version tag, e.g. v1.77.2.
  String version,

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
    version: version,
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
/// direct API, so ask the OS: uname -m where it exists,
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

/// Reads the `version:` field of a package's pubspec.yaml — the
/// thermion_dart version is part of the matcId. Returns 'unversioned'
/// when the file has no version (e.g. a path dependency under development).
Future<String> readPubspecVersion(Directory packageRoot) async {
  final pubspec = File(p.join(packageRoot.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return 'unversioned';
  final lines = await pubspec.readAsLines();
  for (final line in lines) {
    final match = RegExp(r'^version:\s*(\S+)').firstMatch(line);
    if (match != null) return match.group(1)!;
  }
  return 'unversioned';
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
      '-a',
      'webgpu',
      '-o',
      smokeOut.path,
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
    try {
      await fetch(Uri.parse(spec.url), zipFile);
    } catch (e) {
      throw MaterialToolsError(
        'Could not download the Filament tools for material compilation.\n'
        '  URL: ${spec.url}\n'
        '  Filament version: ${spec.version}\n'
        '  Artifact: ${spec.zipName}\n'
        '  Cause: $e\n'
        'Material compilation needs these tools and there is no cached copy '
        'under ${toolsDir.path}. Restore network access (or pre-populate that '
        'cache) and re-run the build.',
      );
    }
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
      'bin/resgen for this host (${spec.hostPlatform}). The pinned Filament '
      'version needs a Build Filament workflow run that ships the shader '
      'tools in its release zip.',
    );
  }
  await _makeExecutable([matc, resgen]);
  if (!await toolsOk()) {
    // A stale tools dir must not survive a failed smoke test.
    toolsDir.deleteSync(recursive: true);
    throw MaterialToolsError(
      'matc from ${spec.url} does not support -a webgpu (smoke test failed '
      'after a fresh download). The R2 artifact was built without '
      'FILAMENT_SUPPORTS_WEBGPU; re-run the Build Filament workflow for the '
      'pinned Filament version.',
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

//
// Compilation planning
//

/// Why a material needs recompiling / what this run will do.
class MaterialCompilePlan {
  MaterialCompilePlan({
    required this.toCompile,
    required this.skipped,
    required this.reason,
    required this.staleOutputs,
  });

  /// Inputs that must be recompiled, in input order.
  final List<File> toCompile;

  /// Inputs that are up to date and why (one line each).
  final Map<File, String> skipped;

  /// Human-readable reason for a full rebuild, or null for an incremental
  /// run.
  final String? reason;

  /// Output files (names, relative to the output dir) whose inputs were
  /// removed from the configuration; deleted after a successful run.
  final List<String> staleOutputs;
}

/// Decides what (if anything) must be recompiled:
///
///   - no manifest            -> compile everything
///   - matcId differs         -> recompile EVERYTHING, even with unchanged
///                               .mat files (the core requirement: a
///                               Filament/thermion bump ships a new matc and
///                               every blob must be rebuilt)
///   - backends/resgen differ -> recompile everything (config change)
///   - cached matc hash moved -> recompile everything
///   - input added/removed/hash changed -> recompile that input
///   - output file missing    -> recompile that input (the manifest alone is
///                               never trusted)
///   - else                   -> skip, with a reason per input
MaterialCompilePlan planMaterialCompilation({
  required Directory appRoot,
  required List<File> inputs,
  required Map<File, String> inputHashes,
  required Directory outputDir,
  required String matcId,
  required List<String> backends,
  required bool resgen,
  String? matcSha256,

  /// Resolves the resgen symbol prefix of an input (null = the stem), so
  /// presence checks match the files a custom prefix actually produces.
  String? Function(File input)? resgenPrefixFor,
}) {
  final manifest = readMaterialsManifest(File(p.join(outputDir.path, materialManifestName)));
  final stems = checkOutputStems(inputs);

  if (manifest == null) {
    return MaterialCompilePlan(
      toCompile: List.of(inputs),
      skipped: const {},
      reason: 'no manifest in ${outputDir.path} — compiling everything',
      staleOutputs: const [],
    );
  }

  String? fullReason;
  if (manifest.matcId != matcId) {
    fullReason =
        'matcId changed (${_shortId(manifest.matcId)} -> '
        '${_shortId(matcId)}) — a new Filament/thermion_dart matc '
        'requires every material to be rebuilt';
  } else if (!listEquals(manifest.backends, backends)) {
    fullReason =
        'backends changed (${manifest.backends.join(',')} -> '
        '${backends.join(',')})';
  } else if (manifest.resgen != resgen) {
    fullReason = 'resgen changed (${manifest.resgen} -> $resgen)';
  } else if (matcSha256 != null && manifest.matcSha256 != null && manifest.matcSha256 != matcSha256) {
    fullReason = 'the cached matc binary changed — rebuilding everything';
  }

  final currentKeys = inputs.map((input) => _manifestKey(input, appRoot)).toSet();
  final staleOutputs = <String>[];
  manifest.outputs.forEach((input, names) {
    if (!currentKeys.contains(input)) {
      staleOutputs.addAll(names);
    }
  });

  if (fullReason != null) {
    return MaterialCompilePlan(
      toCompile: List.of(inputs),
      skipped: const {},
      reason: fullReason,
      staleOutputs: staleOutputs,
    );
  }

  final toCompile = <File>[];
  final skipped = <File, String>{};
  for (final input in inputs) {
    final recorded = manifest.inputs[_manifestKey(input, appRoot)];
    final stem = stems[input]!;
    final outputsPresent = expectedOutputNames(
      stem,
      resgen: resgen,
      prefix: resgenPrefixFor?.call(input),
    ).every((name) => File(p.join(outputDir.path, name)).existsSync());
    if (recorded == null) {
      toCompile.add(input);
    } else if (recorded != inputHashes[input]) {
      toCompile.add(input);
    } else if (!outputsPresent) {
      toCompile.add(input);
    } else {
      skipped[input] = 'unchanged (hash ${_shortId(recorded)})';
    }
  }
  return MaterialCompilePlan(toCompile: toCompile, skipped: skipped, reason: null, staleOutputs: staleOutputs);
}

/// The manifest key for an input: its path relative to the app root when it
/// lives under it (stable, readable), else its absolute path.
String _manifestKey(File input, Directory appRoot) {
  return p.isWithin(appRoot.path, input.path) ? p.relative(input.path, from: appRoot.path) : input.path;
}

//
// Compilation
//

/// Result of [compileUserMaterials].
typedef UserMaterialsResult = ({
  /// The expanded `.mat` inputs (the hook declares them as dependencies).
  List<File> inputs,

  /// The directory the `.filamat` (and optional `.c`/`.h`) files land in.
  Directory outputDir,

  /// How many materials this run compiled (0 = fully up to date).
  int compiled,

  /// How many materials were skipped as up to date.
  int skipped,

  /// Whether the matc/resgen pair had to be downloaded this run.
  bool toolsDownloaded,
});

/// End-to-end entry point used by the build hook.
///
/// Expands [config] against [appRoot], plans the work from the manifest in
/// the output directory and compiles exactly what is stale — nothing at all
/// (no tool download, no matc run) when everything is up to date.
///
/// Every output is written atomically (temp file, then rename) and the
/// manifest is written LAST, so an interrupted or failing run never leaves
/// a half-written output set that the manifest would vouch for.
///
/// Throws [MaterialToolsError] (configuration/tool/download problems) and
/// [MaterialGenerationError] (matc/resgen failed; the tool's stderr is in
/// the message) — the caller must let these fail the build.
Future<UserMaterialsResult> compileUserMaterials({
  required Directory appRoot,
  required MaterialCompilationConfig config,
  required String filamentVersion,
  required String packageVersion,
  required String hostOS,
  required String hostArch,
  String? toolsCacheRoot,
  UrlDownloader? download,
  ToolProcess? runProcess,
  void Function(String message)? onLog,
}) async {
  final log = onLog ?? (_) {};
  final spec = resolveMaterialToolsSpec(version: filamentVersion, hostOS: hostOS, hostArch: hostArch);

  final inputs = expandMaterialInputs(appRoot: appRoot, inputs: config.inputs);
  final stems = checkOutputStems(inputs);
  final inputHashes = <File, String>{};
  for (final input in inputs) {
    inputHashes[input] = sha256.convert(await input.readAsBytes()).toString();
  }

  final outputDir = Directory(p.isAbsolute(config.output) ? config.output : p.join(appRoot.path, config.output));
  final manifestFile = File(p.join(outputDir.path, materialManifestName));

  // The sha256 of the cached matc binary, when the cache is warm. It is
  // compared against the manifest's matcSha256 (not folded into the
  // matcId): a re-uploaded artifact for the same version must rebuild
  // everything, but an empty cache must not (the version tuple in the
  // matcId already covers version changes).
  final cacheRoot =
      toolsCacheRoot ??
      defaultMaterialToolsCacheRoot() ??
      p.join(appRoot.path, '.dart_tool', 'thermion_dart', 'filament-tools');
  final cachedMatc = File(p.join(cacheRoot, spec.cacheDirName, 'bin', 'matc${spec.exeSuffix}'));
  final cachedMatcHash = cachedMatc.existsSync() ? sha256.convert(await cachedMatc.readAsBytes()).toString() : null;

  final matcId = computeMatcId(
    filamentVersion: filamentVersion,
    packageVersion: packageVersion,
    hostPlatform: spec.hostPlatform,
    hostArch: hostArch,
  );

  final plan = planMaterialCompilation(
    appRoot: appRoot,
    inputs: inputs,
    inputHashes: inputHashes,
    outputDir: outputDir,
    matcId: matcId,
    backends: config.backends,
    resgen: config.resgen,
    matcSha256: cachedMatcHash,
    resgenPrefixFor: (input) =>
        config.resgenPrefixes[stems[input]!] ?? config.resgenPrefixes[p.basenameWithoutExtension(input.path)],
  );
  final previousManifest = readMaterialsManifest(manifestFile);

  if (plan.toCompile.isEmpty && plan.staleOutputs.isEmpty) {
    log(
      'thermion materials: all ${inputs.length} up to date '
      '(matcId ${_shortId(matcId)}); nothing compiled into ${outputDir.path}',
    );
    return (inputs: inputs, outputDir: outputDir, compiled: 0, skipped: inputs.length, toolsDownloaded: false);
  }

  if (plan.reason != null) {
    log('thermion materials: ${plan.reason}');
  }

  if (plan.toCompile.isEmpty) {
    // Only stale outputs to clean up (an input was removed from the
    // config): no tools are needed for that.
    outputDir.createSync(recursive: true);
    _removeStaleOutputs(plan.staleOutputs, outputDir, log);
    _writeManifest(
      manifestFile,
      matcId: matcId,
      matcSha256: cachedMatcHash ?? previousManifest?.matcSha256,
      backends: config.backends,
      resgen: config.resgen,
      inputs: {for (final input in inputs) _manifestKey(input, appRoot): inputHashes[input]!},
      previousOutputs: previousManifest?.outputs ?? const {},
    );
    log(
      'thermion materials: 0 of ${inputs.length} needed compiling '
      '(cleaned ${plan.staleOutputs.length} stale outputs in ${outputDir.path})',
    );
    return (inputs: inputs, outputDir: outputDir, compiled: 0, skipped: inputs.length, toolsDownloaded: false);
  }

  final tools = await ensureMaterialTools(
    spec: spec,
    cacheRoot: Directory(cacheRoot),
    download: download,
    runProcess: runProcess,
    onLog: onLog,
  );
  final usedMatcHash = sha256.convert(await tools.matc.readAsBytes()).toString();

  outputDir.createSync(recursive: true);
  // Staging dirs from interrupted runs must not accumulate.
  for (final entity in outputDir.listSync()) {
    if (entity is Directory && p.basename(entity.path).startsWith('.staging-')) {
      entity.deleteSync(recursive: true);
    }
  }

  final writtenOutputs = <String, List<String>>{};
  for (final input in plan.toCompile) {
    final stem = stems[input]!;
    final prefix = config.resgenPrefixes[stem] ?? config.resgenPrefixes[p.basenameWithoutExtension(input.path)] ?? stem;
    writtenOutputs[_manifestKey(input, appRoot)] = await _compileOne(
      input: input,
      stem: stem,
      prefix: prefix,
      backends: config.backends,
      runResgen: config.resgen,
      outputDir: outputDir,
      matc: tools.matc,
      resgen: tools.resgen,
      runProcess: runProcess ?? _defaultRunProcess,
      log: log,
    );
  }

  // Only after every compile succeeded: drop outputs of removed inputs.
  _removeStaleOutputs(plan.staleOutputs, outputDir, log);

  final inputsByManifestKey = <String, String>{
    for (final input in inputs) _manifestKey(input, appRoot): inputHashes[input]!,
  };
  _writeManifest(
    manifestFile,
    matcId: matcId,
    matcSha256: usedMatcHash,
    backends: config.backends,
    resgen: config.resgen,
    inputs: inputsByManifestKey,
    previousOutputs: {...?previousManifest?.outputs, ...writtenOutputs},
    restrictTo: inputsByManifestKey.keys.toSet(),
  );

  final summary = StringBuffer()
    ..write(
      'thermion materials: compiled ${plan.toCompile.length} of ${inputs.length} '
      'into ${outputDir.path} (backends ${config.backends.join(',')}',
    );
  if (config.resgen) summary.write(', resgen on');
  if (plan.skipped.isNotEmpty) summary.write('; ${plan.skipped.length} skipped as up to date');
  if (plan.reason != null) summary.write('; full rebuild');
  summary.write(')');
  log(summary.toString());

  return (
    inputs: inputs,
    outputDir: outputDir,
    compiled: plan.toCompile.length,
    skipped: plan.skipped.length,
    toolsDownloaded: tools.downloaded,
  );
}

void _removeStaleOutputs(List<String> staleOutputs, Directory outputDir, void Function(String) log) {
  for (final name in staleOutputs.toSet()) {
    final file = File(p.join(outputDir.path, name));
    if (file.existsSync()) {
      file.deleteSync();
      log('thermion materials: removed stale output $name (input removed from the config)');
    }
  }
}

/// Writes the manifest (atomically) — always the LAST write, and only after
/// every compile succeeded.
void _writeManifest(
  File manifestFile, {
  required String matcId,
  required String? matcSha256,
  required List<String> backends,
  required bool resgen,
  required Map<String, String> inputs,
  required Map<String, List<String>> previousOutputs,
  Set<String>? restrictTo,
}) {
  final outputs = {...previousOutputs};
  if (restrictTo != null) {
    outputs.removeWhere((key, _) => !restrictTo.contains(key));
  }
  _writeAtomically(
    manifestFile,
    encodeMaterialsManifest(
      matcId: matcId,
      matcSha256: matcSha256,
      backends: backends,
      resgen: resgen,
      inputs: inputs,
      outputs: outputs,
    ),
  );
}

/// Compiles one material into [outputDir]:
///
///   matc -a b1 -a b2 ... -o <staging>/<stem>.filamat <input>
///   resgen -c -p <prefix> -x <staging>/ <staging>/<stem>.filamat   (opt)
///
/// Everything is produced inside a staging directory inside [outputDir]
/// (same filesystem, so renames are atomic) and renamed into place only
/// once every tool succeeded — a failure leaves the previous outputs and
/// the manifest untouched.
Future<List<String>> _compileOne({
  required File input,
  required String stem,
  required String prefix,
  required List<String> backends,
  required bool runResgen,
  required Directory outputDir,
  required File matc,
  required File resgen,
  required ToolProcess runProcess,
  required void Function(String message) log,
}) async {
  final staging = Directory(p.join(outputDir.path, '.staging-$pid-${stem}'))..createSync(recursive: true);
  try {
    final filamat = File(p.join(staging.path, '$stem.filamat'));
    final matcArgs = [
      for (final backend in backends) ...['-a', backend],
      '-o',
      filamat.path,
      input.path,
    ];
    final matcResult = await runProcess(matc.path, matcArgs);
    if (matcResult.exitCode != 0 || !filamat.existsSync()) {
      throw MaterialGenerationError(
        'matc failed for ${input.path}:\n'
        '${matcResult.stderr.isNotEmpty ? matcResult.stderr : matcResult.stdout}',
      );
    }

    if (runResgen) {
      final resgenResult = await runProcess(resgen.path, [
        '-c',
        '-p',
        prefix,
        '-x',
        '${staging.path}${p.separator}',
        filamat.path,
      ]);
      if (resgenResult.exitCode != 0) {
        throw MaterialGenerationError(
          'resgen failed for ${input.path}:\n'
          '${resgenResult.stderr.isNotEmpty ? resgenResult.stderr : resgenResult.stdout}',
        );
      }
    }

    // Move every produced file into place atomically.
    final produced = staging.listSync().whereType<File>().map((f) => f.path).toList()..sort();
    if (produced.isEmpty) {
      throw MaterialGenerationError('matc produced no output for ${input.path}.');
    }
    final written = <String>[];
    for (final producedPath in produced) {
      final name = p.basename(producedPath);
      File(producedPath).renameSync(p.join(outputDir.path, name));
      written.add(name);
    }
    log('thermion materials: $input -> ${written.join(', ')}');
    return written;
  } finally {
    if (staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
  }
}

/// Writes [content] to [file] atomically: temp file beside it, then rename.
void _writeAtomically(File file, String content) {
  file.parent.createSync(recursive: true);
  final temp = File('${file.path}.tmp-${pid}');
  temp.writeAsStringSync(content, flush: true);
  temp.renameSync(file.path);
}
