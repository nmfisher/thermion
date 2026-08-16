import 'package:thermion_dart/thermion_dart.dart';

/// Exports a list of flat meshes ([RawMesh]) to a model-file byte buffer.
///
/// This is the export counterpart of [ModelFileImporter]: it takes the same
/// mesh data the importers produce and writes it back out as a single model
/// file. All meshes go into one scene — one named mesh (and one material,
/// named after [RawMesh.materialName]) per entry, under a single root node.
///
/// Throws [UnsupportedError] on builds without export support,
/// [ArgumentError] for unsupported formats or an empty mesh list, and a
/// generic [Exception] when the native export fails.
abstract class ModelFileExporter {
  /// Whether this exporter is available in the current build.
  bool get isSupported;

  /// Export [meshes] and return the encoded file bytes.
  ///
  /// [formatHint] is the file extension without the dot (e.g. "fbx"). The
  /// meshes are not consumed — their buffers are copied into the export
  /// scene, so callers keep ownership and dispose them as usual.
  Uint8List export(List<RawMesh> meshes, {required String formatHint});
}
