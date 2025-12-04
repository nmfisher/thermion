// import 'package:thermion_dart/thermion_dart.dart';
// import 'package:thermion_dart/src/filament/src/interface/gltf_mesh_data.dart';

// class FFIGltfMeshData extends GltfMeshData {
//   FFIGltfMeshData({
//     required super.vertices,
//     super.indices,
//     required super.primitiveType,
//   });

//   /// Parse glTF file and extract geometry data for physics collision detection.
//   /// Returns vertex positions (xyz) and optional indices.
//   /// If [meshName] is specified, only extracts data for that specific mesh.
//   static Future<GltfMeshData> parse(Uint8List data, {String? meshName}) async {
//     late Pointer stackPtr;
//     if (FILAMENT_WASM) {
//       // stackPtr = stackSave();
//     }

//     final meshNamePtr = meshName != null
//       ? meshName.toNativeUtf8().cast<Char>()
//       : nullptr;

//     final meshData = Struct.create<TGltfMeshData>();

//     try {
//       final result = GltfParser_parseBuffer(
//         data.address,
//         data.length,
//         meshNamePtr,
//         meshData.address,
//       );

//       if (result != 0) {
//         throw Exception("Failed to parse glTF for physics (error code: $result)");
//       }

//       // Copy to Dart lists
//       final vertices = Float32List(meshData.vertexCount);
//       for (int i = 0; i < meshData.vertexCount; i++) {
//         vertices[i] = meshData.vertices[i];
//       }

//       Uint32List? indices;
//       if (meshData.indices != nullptr && meshData.indexCount > 0) {
//         indices = Uint32List(meshData.indexCount);
//         for (int i = 0; i < meshData.indexCount; i++) {
//           indices[i] = meshData.indices[i];
//         }
//       }

//       GltfParser_freeMeshData(meshData.address);

//       return FFIGltfMeshData(
//         vertices: vertices,
//         indices: indices,
//         primitiveType: PrimitiveType.values[meshData.primitiveType],
//       );
//     } finally {
//       if (meshNamePtr != nullptr) {
//         free(meshNamePtr);
//       }
//       if (FILAMENT_WASM) {
//         // stackRestore(stackPtr);
//         data.free();
//       }
//     }
//   }
// }
