/// Pure naming/normalization for the prebuilt web engine artifacts.
///
/// Kept free of any build-hook or native-assets imports so it can be unit
/// tested directly (see test/web_artifacts_test.dart) and imported by
/// hook/build.dart via a relative path.
library;

/// R2 base for all prebuilt artifacts (Filament libs and web engine zips).
const String webR2BaseUrl = 'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev';

/// Raw `web_variant` user-define values and their canonical forms.
const String webVariantMainThread = 'main_thread';

/// Resolved web engine variant: how its R2 zip and cache directory are named.
typedef WebVariantResolution = ({
  /// Suffix inserted into artifact names, e.g. `thermion_dart-<sha>-web` +
  /// [zipSuffix] + `.zip`. Empty for the default (worker) engine.
  String zipSuffix,

  /// Segment appended to the shared `.dart_tool/thermion_dart/web/<version>`
  /// cache path so variants never share a directory (the `success` token
  /// would otherwise mask the wrong contents).
  String cacheSuffix,

  /// Non-fatal diagnostics to log.
  List<String> warnings,
});

/// Normalizes the `web_variant` user define.
///
/// [raw] is the raw user-define value (null when unset). Accepted value:
/// `main_thread`. Unknown values emit a warning and fall back to the default
/// (worker) engine rather than failing the build — the default artifact must
/// keep working.
WebVariantResolution resolveWebVariant(Object? raw) {
  if (raw == null) {
    return (zipSuffix: '', cacheSuffix: '', warnings: const []);
  }
  final value = raw is String ? raw.trim() : raw.toString();
  if (value.isEmpty || value == 'worker' || value == 'default') {
    // Explicitly selecting the default is a no-op, not a warning.
    return (zipSuffix: '', cacheSuffix: '', warnings: const []);
  }
  if (value.toLowerCase() == webVariantMainThread) {
    return (zipSuffix: '-main-thread', cacheSuffix: '-main-thread', warnings: const []);
  }
  return (
    zipSuffix: '',
    cacheSuffix: '',
    warnings: [
      "Unknown web_variant '$value' (raw: $raw). "
          "Valid values: $webVariantMainThread, worker, default. "
          'Falling back to the default (worker) web engine.',
    ],
  );
}

/// Zip name for the web engine artifact on R2:
/// `thermion_dart-<version>-web.zip` / `thermion_dart-<version>-web-main-thread.zip`.
String webArtifactZipName(String version, String zipSuffix) => 'thermion_dart-$version-web$zipSuffix.zip';

/// Full R2 URL for the web engine artifact.
String webArtifactUrl(String version, String zipSuffix) => '$webR2BaseUrl/${webArtifactZipName(version, zipSuffix)}';

/// Build-directory (relative to `thermion_dart/native/web/`) whose
/// `build/out/` holds the engine for [zipSuffix] — the directory `web_local`
/// copies from.
String webLocalBuildDir(String zipSuffix) => zipSuffix.isEmpty ? 'build' : 'build-main-thread';
