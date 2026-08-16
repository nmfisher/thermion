/// Unified model-file import facade.
///
/// Every path that decomposes a model file into flat meshes goes through
/// [ModelFileImporter] and produces [RawMesh]es, regardless of whether the
/// file is parsed by Assimp or cgltf underneath.
export 'src/model_file_importer.dart';
export 'src/raw_mesh.dart';
export 'src/assimp_importer.dart';
export 'src/cgltf_importer.dart';
