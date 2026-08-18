/// Pure resolution of which material backend variant to compile into a build.
///
/// Kept free of any build-hook or native-assets imports so it can be unit
/// tested directly (see test/material_backend_resolution_test.dart) and
/// imported by hook/build.dart via a relative path.
library;

/// Thrown when a `materials.backends` user-define configuration is invalid.
class MaterialBackendError extends FormatException {
  MaterialBackendError(super.message);
}

/// The variant to compile in: a resource-file suffix (e.g. `_apple`) plus the
/// C preprocessor define that dispatches the forwarding headers, plus any
/// non-fatal diagnostics to log.
typedef MaterialBackendResolution = ({String suffix, String define, List<String> warnings});

const _validOsKeys = ['ios', 'macos', 'apple', 'android', 'linux', 'windows'];

/// Resolves the material variant suffix and [THERMION_MATERIAL_*] define for
/// the current target.
///
/// [backendsConfig] is the raw `materials.backends` map from user defines, or
/// null when unset (defaults apply). [targetOS] is a lowercase OS name:
/// ios, macos, android, linux, or windows. [backendOverride] is the value of
/// the flat `backend` user define when it selected an explicit variant
/// (webgpu/webgl2/hybrid), null otherwise.
///
/// Precedence: if `materials.backends` covers the target OS it wins (warning
/// when an override is also set); otherwise the override applies if set;
/// otherwise the platform default (all backends).
///
/// Throws [MaterialBackendError] for invalid configuration.
MaterialBackendResolution resolveMaterialBackend({
  required Map<String, dynamic>? backendsConfig,
  required String targetOS,
  String? backendOverride,
}) {
  final warnings = <String>[];

  String? effectiveKey;
  if (backendsConfig != null) {
    // Normalize keys so lookups and validation agree on case. Validate up
    // front so typos surface even when they don't affect the current target.
    final normalized = <String, dynamic>{
      for (final entry in backendsConfig.entries) entry.key.toLowerCase(): entry.value,
    };
    for (final key in normalized.keys) {
      if (key == 'web') {
        warnings.add(
          "materials.backends.web is ignored: the web WASM is a prebuilt "
          "artifact whose material variant is fixed at build time. Use the "
          "flat 'backend' user define for web targets.",
        );
        continue;
      }
      if (!_validOsKeys.contains(key)) {
        throw MaterialBackendError(
          "Unknown OS key '$key' in materials.backends. "
          "Valid keys: ${_validOsKeys.join(', ')} (web is not configurable).",
        );
      }
    }

    // The apple alias covers both ios and macos; an explicit ios/macos key
    // wins over it.
    effectiveKey = normalized.containsKey(targetOS)
        ? targetOS
        : (targetOS == 'ios' || targetOS == 'macos') && normalized.containsKey('apple')
        ? 'apple'
        : null;

    if (effectiveKey != null) {
      final backends = _normalizeBackends(normalized[effectiveKey], effectiveKey, warnings);
      if (backends.isEmpty) {
        throw MaterialBackendError("materials.backends.$effectiveKey resolved to an empty backend list.");
      }
      final suffix = _suffixFor(Set.of(backends), targetOS);
      if (suffix == null) {
        throw MaterialBackendError(
          "Unsupported backend combination for $targetOS: ${backends.join(' + ')}. "
          "Valid combinations: "
          "${targetOS == 'ios' || targetOS == 'macos' ? 'metal' : 'opengl, vulkan, or opengl + vulkan'}.",
        );
      }
      if (backendOverride != null) {
        warnings.add(
          "Both 'backend' ($backendOverride) and 'materials.backends' are "
          "set; materials.backends takes precedence for this target.",
        );
      }
      return (suffix: suffix, define: _defineFor(suffix), warnings: warnings);
    }
  }

  // Target OS not covered by materials.backends (or no config): the flat
  // backend override applies if set, otherwise the platform default.
  final overrideSuffix = _overrideSuffixes[backendOverride];
  if (overrideSuffix != null) {
    return (suffix: overrideSuffix, define: _defineFor(overrideSuffix), warnings: warnings);
  }
  if (backendOverride != null && backendOverride != 'native') {
    throw MaterialBackendError(
      "Unknown backend '$backendOverride'. Valid values: webgpu, webgl2, "
      "hybrid, native.",
    );
  }
  final suffix = _defaultSuffix(targetOS);
  return (suffix: suffix, define: _defineFor(suffix), warnings: warnings);
}

const _overrideSuffixes = {'webgpu': '_webgpu', 'webgl2': '_web_webgl', 'hybrid': '_web_combined'};

String _defaultSuffix(String targetOS) {
  switch (targetOS) {
    case 'ios':
    case 'macos':
      return '_apple';
    case 'android':
      return '_android';
    default:
      return '_desktop';
  }
}

String _defineFor(String suffix) => 'THERMION_MATERIAL${suffix.toUpperCase()}';

String? _suffixFor(Set<String> backends, String targetOS) {
  if (backends.length == 1) {
    switch (backends.single) {
      case 'metal':
        return '_apple';
      case 'opengl':
        return '_opengl';
      case 'vulkan':
        return '_vulkan';
    }
    return null;
  }
  // {opengl, vulkan} is the only supported multi-backend set.
  if (backends.containsAll(['opengl', 'vulkan']) && backends.length == 2) {
    return targetOS == 'android' ? '_android' : '_desktop';
  }
  return null;
}

/// Accepts a string or a list of strings; validates tokens for [osKey].
List<String> _normalizeBackends(dynamic raw, String osKey, List<String> warnings) {
  if (raw is String) return _normalizeBackends([raw], osKey, warnings);
  if (raw is! List) {
    throw MaterialBackendError(
      "materials.backends.$osKey must be a backend name or a list of backend "
      "names, got ${raw.runtimeType}.",
    );
  }
  final apple = osKey == 'ios' || osKey == 'macos' || osKey == 'apple';
  final valid = apple ? ['metal'] : ['opengl', 'vulkan'];
  final result = <String>[];
  for (final entry in raw) {
    if (entry is! String) {
      throw MaterialBackendError(
        "materials.backends.$osKey entries must be strings, got "
        "${entry.runtimeType}.",
      );
    }
    final token = entry.toLowerCase();
    if (token == 'webgpu' || token == 'webgl2') {
      warnings.add(
        "'$token' is ignored in materials.backends.$osKey; use the flat "
        "'backend' user define to select WebGPU variants.",
      );
      continue;
    }
    if (!valid.contains(token)) {
      throw MaterialBackendError(
        "Invalid backend '$token' for $osKey in materials.backends. "
        "Valid backends for ${apple ? 'iOS/macOS' : osKey}: ${valid.join(', ')}.",
      );
    }
    if (!result.contains(token)) result.add(token);
  }
  return result;
}
