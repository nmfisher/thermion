/// Unified model-file import/export facade.
///
/// Every path that decomposes a model file into flat meshes goes through
/// [ModelFileImporter] and produces [RawMesh]es, regardless of whether the
/// file is parsed by Assimp or cgltf underneath; [ModelFileExporter] writes
/// those meshes back out to a model file.
export 'src/model_file_importer.dart';
export 'src/model_file_exporter.dart';
export 'src/raw_mesh.dart';
export 'src/assimp_importer.dart';
export 'src/assimp_exporter.dart';
export 'src/cgltf_importer.dart';
