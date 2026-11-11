/// Pure naming/resolution for the prebuilt Filament library artifacts.
///
/// Kept free of build-hook and native-assets imports so it can be unit
/// tested directly (see test/filament_artifacts_test.dart) and imported by
/// hook/build.dart via a relative path — the same layout as
/// web_artifacts.dart.
///
/// ## Content-addressed artifacts + pin
///
/// Historically the Filament zips lived at *mutable* keys
/// (`filament-<version>-<platform>-<variant>.zip`): refreshing an artifact
/// meant overwriting the exact object production consumers download.
///
/// New artifacts are content-addressed instead:
///
///   filament-<version>-<platform>-<variant>-<hash16>.zip
///
/// where `<hash16>` is the first 16 hex chars of the zip's SHA-256. The
/// full digest is recorded in a shipped pin file, `filament.libs.json`
/// (package root of thermion_dart):
///
///   { "macos/release": "<64 hex sha256>", "web/release": "...", ... }
///
/// Keys are `<platform>/<variant>` using the hook's platform slugs:
/// macos, ios, ios-simulator, android, linux, linux-arm64, windows, web;
/// variants release/debug.
///
/// Resolution: a pinned entry selects the hash-suffixed key and the hook
/// verifies the download against the full digest. An absent entry falls
/// back to the legacy mutable key (still required for already-published
/// thermion versions and the transition period). Flipping the pin is the
/// rollout; reverting it is the rollback — canonical objects are never
/// overwritten by the sanctioned publishing path.
library;

import 'dart:convert';

/// R2 base for all prebuilt artifacts (Filament libs and web engine zips).
/// Same bucket as web_artifacts.dart's webR2BaseUrl.
const String filamentR2BaseUrl =
    'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev';

/// Name of the shipped pin file at the thermion_dart package root.
const String filamentPinFileName = 'filament.libs.json';

/// Number of leading hex chars of the SHA-256 used in artifact filenames.
/// 16 hex = 64 bits: collision-proof for the handful of artifacts we keep,
/// while keeping names readable. The pin stores the FULL digest and the
/// hook verifies downloads against it.
const int filamentHashPrefixLength = 16;

/// Platform slugs that may appear in pin keys (the hook's `platform`
/// values, including the iOS-simulator and linux-arm64 splits).
const Set<String> filamentPlatforms = {
  'macos',
  'ios',
  'ios-simulator',
  'android',
  'linux',
  'linux-arm64',
  'windows',
  'web',
};

/// A parsed pin: `<platform>/<variant>` → full lowercase SHA-256 hex.
typedef FilamentPin = Map<String, String>;

/// Result of resolving one artifact request against the pin.
typedef FilamentArtifactResolution = ({
  /// Full R2 URL to download.
  String url,

  /// Zip base name (last URL segment); also the on-disk zip name.
  String zipName,

  /// Full expected SHA-256 (null for legacy/unpinned artifacts).
  String? sha256,

  /// Cache-directory suffix: `-<hash16>` for pinned artifacts, '' for
  /// legacy. Appended to the version-scoped cache path so a pin flip
  /// lands in a fresh directory and the old `success` token cannot mask
  /// new contents.
  String cacheSuffix,

  /// Non-fatal diagnostics to log.
  List<String> warnings,
});

/// Parses pin file contents. Accepts a JSON object mapping
/// `<platform>/<variant>` keys to 64-char hex SHA-256 strings.
///
/// Lenient like resolveWebVariant: malformed entries are dropped with a
/// warning rather than failing the build — an unusable pin must degrade to
/// the legacy artifacts, never break consumers. Unknown platforms, bad
/// digests and non-string values are all rejected per-entry.
FilamentPin parseFilamentPin(String? contents, {List<String>? warnings}) {
  final sink = warnings ?? <String>[];
  final pin = <String, String>{};
  if (contents == null || contents.trim().isEmpty) return pin;
  Object? decoded;
  try {
    decoded = jsonDecode(contents);
  } catch (e) {
    sink.add('$filamentPinFileName is not valid JSON ($e); '
        'using legacy artifact keys.');
    return pin;
  }
  if (decoded is! Map) {
    sink.add('$filamentPinFileName must be a JSON object; '
        'using legacy artifact keys.');
    return pin;
  }
  for (final entry in decoded.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || !_validPinKey(key)) {
      sink.add("Ignoring pin entry '$key': expected '<platform>/<variant>' "
          'with platform in ${filamentPlatforms.toList()..sort()} '
          'and variant release|debug.');
      continue;
    }
    if (value is! String || !_isSha256Hex(value)) {
      sink.add("Ignoring pin entry '$key': value must be a 64-char hex "
          'SHA-256 digest.');
      continue;
    }
    pin[key] = value.toLowerCase();
  }
  return pin;
}

bool _validPinKey(String key) {
  final parts = key.split('/');
  if (parts.length != 2) return false;
  return filamentPlatforms.contains(parts[0]) &&
      (parts[1] == 'release' || parts[1] == 'debug');
}

bool _isSha256Hex(String value) {
  if (value.length != 64) return false;
  for (final unit in value.codeUnits) {
    final isDigit = unit >= 0x30 && unit <= 0x39; // 0-9
    final isLower = unit >= 0x61 && unit <= 0x66; // a-f
    final isUpper = unit >= 0x41 && unit <= 0x46; // A-F
    if (!isDigit && !isLower && !isUpper) return false;
  }
  return true;
}

/// Legacy (mutable) zip name — kept for already-published thermion
/// versions and as the fallback when the pin has no entry.
String legacyFilamentZipName(String version, String platform, String variant) =>
    'filament-$version-$platform-$variant.zip';

/// Content-addressed zip name for a full SHA-256 digest.
String hashedFilamentZipName(
        String version, String platform, String variant, String sha256) =>
    'filament-$version-$platform-$variant-${sha256.substring(0, filamentHashPrefixLength)}.zip';

/// Resolves the artifact for [version]/[platform]/[variant] against [pin].
///
/// Pinned → hash-suffixed URL + full digest + `-<hash16>` cache suffix.
/// Unpinned → legacy URL, no digest, no cache suffix (byte-compatible with
/// the pre-pin hook, including existing caches).
FilamentArtifactResolution resolveFilamentArtifact(
  String version,
  String platform,
  String variant,
  FilamentPin pin,
) {
  final sha = pin['$platform/$variant'];
  if (sha == null) {
    final name = legacyFilamentZipName(version, platform, variant);
    return (
      url: '$filamentR2BaseUrl/$name',
      zipName: name,
      sha256: null,
      cacheSuffix: '',
      warnings: const [],
    );
  }
  final name = hashedFilamentZipName(version, platform, variant, sha);
  return (
    url: '$filamentR2BaseUrl/$name',
    zipName: name,
    sha256: sha,
    cacheSuffix: '-${sha.substring(0, filamentHashPrefixLength)}',
    warnings: const [],
  );
}

/// Serializes a pin deterministically (sorted keys, 2-space indent,
/// trailing newline) so CI pin-flip commits produce minimal, stable diffs.
String encodeFilamentPin(FilamentPin pin) {
  final keys = pin.keys.toList()..sort();
  final sorted = {for (final k in keys) k: pin[k]};
  return '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
}
