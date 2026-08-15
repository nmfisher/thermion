import 'package:thermion_dart/thermion_dart.dart';

/// Represents a single mesh parsed from a model file (OBJ/FBX/glTF/STL/PLY/...).
///
/// Deprecated: this is a thin source-compatibility alias for [RawMesh].
/// The Assimp FFI call sequence now lives in [AssimpImporter].
@Deprecated(
  'Use RawMesh / AssimpImporter from package:thermion_dart '
  '(see ModelFileImporter). This alias will be removed in a future release.',
)
typedef ImportedMesh = RawMesh;

/// Model importer backed by Assimp.
///
/// Deprecated: use [AssimpImporter] (implementing [ModelFileImporter])
/// instead. Kept because it is referenced from pre-facade call sites.
@Deprecated(
  'Use AssimpImporter from package:thermion_dart '
  '(see ModelFileImporter). This wrapper will be removed in a future release.',
)
class ModelImporter {
  /// Whether Assimp model loading was compiled into this build.
  static bool get isSupported => AssimpImporter().isSupported;

  /// Load a model from a byte buffer using Assimp.
  ///
  /// [formatHint] is the file extension *without* the dot (e.g. "obj",
  /// "fbx", "glb", "stl", "ply"). Assimp uses it to select the right
  /// importer when reading from memory.
  ///
  /// Returns a list of [RawMesh] objects, one for each mesh in the file.
  /// Throws if the file cannot be loaded.
  static List<RawMesh> loadFromBuffer(Uint8List data, {required String formatHint}) =>
      AssimpImporter().parse(data, formatHint: formatHint);
}
