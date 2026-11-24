/// Pure resolution of the `features` user define: compile-time opt-outs for
/// the native libraries (gltfio, KTX/Basis, PNG/JPEG decoding).
///
/// Kept free of any build-hook or native-assets imports so it can be unit
/// tested directly (see test/resolve_pubspec_features_test.dart) and imported
/// by hook/build.dart via a relative path, exactly like
/// `selectBuiltInMaterials` / `resolveBackendUserDefine`.
///
/// Shape (consuming app's pubspec.yaml):
///
/// ```yaml
/// hooks:
///   user_defines:
///     thermion_dart:
///       features:
///         gltf: false            # default true
///         ktx: false             # default true
///         image_decoding: false  # default true
/// ```
///
/// Semantics are opt-out: an absent key (or no `features` map at all) keeps
/// the feature, so existing apps build exactly as before.
library;

import 'material_tools.dart' show MaterialToolsError;

/// Resolved feature switches for one build. Every field is `true` unless the
/// app explicitly disabled it.
typedef ThermionFeatures = ({bool gltf, bool ktx, bool imageDecoding});

/// Keys accepted under `features.*`.
const List<String> featureKeys = ['gltf', 'ktx', 'image_decoding'];

/// The C define each disabled feature adds to the Thermion compile. The
/// headers default every switch to 1, so enabled features pass nothing and
/// default compile commands stay byte-identical.
const Map<String, String> _featureDefines = {
  'gltf': 'THERMION_ENABLE_GLTF',
  'ktx': 'THERMION_ENABLE_KTX',
  'image_decoding': 'THERMION_ENABLE_IMAGE_DECODING',
};

/// Resolves the `features` user define.
///
/// [raw] is `input.userDefines['features']`:
///  - null -> every feature enabled;
///  - a map keyed by [featureKeys] with unquoted YAML booleans;
///  - anything else, or a non-boolean value, throws [MaterialToolsError]
///    naming the key (stricter than `runtime_materials`' warn-and-continue:
///    silently ignoring `gltf: "false"` would ship a 4 MB fatter binary
///    than the user asked for);
///  - an unknown key only warns through [onWarning] (forward compatibility
///    with older hook versions, same as `materials.<unknown>`).
///
/// Cross-feature rule: `gltf: true` together with
/// `ktx: false` or `image_decoding: false` is rejected. Filament's
/// `ResourceLoader` never reports load progress with an empty provider map
/// and silently skips textures whose decoder is missing, so a glTF build
/// without its texture decoders has no defined completion semantics yet.
/// `ktx` and `image_decoding` stay independently switchable when `gltf` is
/// disabled.
ThermionFeatures resolveFeatures(Object? raw, {required void Function(String) onWarning}) {
  if (raw == null) {
    return (gltf: true, ktx: true, imageDecoding: true);
  }
  if (raw is! Map) {
    throw MaterialToolsError(
      'features must be a map in pubspec.yaml (keys: ${featureKeys.join(', ')}), '
      'got ${raw.runtimeType}.',
    );
  }
  final values = <String, bool>{};
  for (final MapEntry(:key, :value) in raw.entries) {
    final name = key.toString();
    if (!featureKeys.contains(name)) {
      onWarning('Unknown key features.$name in pubspec.yaml.');
      continue;
    }
    if (value is! bool) {
      throw MaterialToolsError(
        'features.$name must be true or false (an unquoted YAML boolean), '
        'got $value.',
      );
    }
    values[name] = value;
  }
  final features = (
    gltf: values['gltf'] ?? true,
    ktx: values['ktx'] ?? true,
    imageDecoding: values['image_decoding'] ?? true,
  );
  if (features.gltf && (!features.ktx || !features.imageDecoding)) {
    final disabled = [
      if (!features.ktx) 'features.ktx: false',
      if (!features.imageDecoding) 'features.image_decoding: false',
    ];
    throw MaterialToolsError(
      'features.gltf: true cannot be combined with ${disabled.join(' or ')}: '
      'a glTF build needs its texture decoders (Filament\'s ResourceLoader never '
      'completes an async load with an empty provider map and silently skips '
      'textures whose decoder is missing). Disable features.gltf as well, or '
      'leave the decoders enabled.',
    );
  }
  return features;
}

/// The `THERMION_ENABLE_<FEATURE>` -> `0` entries for every disabled
/// feature, in [featureKeys] order. Enabled features contribute nothing
/// so their compile commands are unchanged.
Map<String, String> disabledFeatureDefines(ThermionFeatures features) {
  final enabled = {'gltf': features.gltf, 'ktx': features.ktx, 'image_decoding': features.imageDecoding};
  return {
    for (final key in featureKeys)
      if (!enabled[key]!) _featureDefines[key]!: '0',
  };
}

/// Whether any feature is disabled, for the web-branch warning (web engines
/// are prebuilt with every feature; `features.*` only affects native builds).
bool anyFeatureDisabled(ThermionFeatures features) => !features.gltf || !features.ktx || !features.imageDecoding;
