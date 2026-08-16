import 'package:thermion_dart/thermion_dart.dart';

/// Parses a model-file byte buffer into a list of flat meshes ([RawMesh]).
///
/// Two implementations sit behind this interface:
///
/// - [AssimpImporter] — any format Assimp reads (OBJ, FBX, glTF/glb, STL,
///   PLY, ...). Requires the native library to be built with Assimp enabled
///   (`assimp: true` under `hooks.user_defines.thermion_dart`), which is
///   opt-in at link time.
/// - [CgltfImporter] — glTF/glb only, via the cgltf parser that ships with
///   the Filament build (always available). Extracts positions/indices
///   (used for physics collision meshes).
///
/// The viewer's `loadModel`/`loadModelFromBuffer` and the physics-side
/// `parseGltf` both route through this facade; neither caller talks to the
/// FFI layer directly.
abstract class ModelFileImporter {
  /// Whether this importer is available in the current build.
  bool get isSupported;

  /// Parse [data] and return one [RawMesh] per mesh in the file.
  ///
  /// [formatHint] is the file extension without the dot (e.g. "obj", "fbx",
  /// "glb"). Assimp needs it to select the right importer when reading from
  /// memory; the cgltf importer ignores it.
  ///
  /// Throws on unsupported builds ([UnsupportedError]) or unparseable files.
  List<RawMesh> parse(Uint8List data, {required String formatHint});
}
