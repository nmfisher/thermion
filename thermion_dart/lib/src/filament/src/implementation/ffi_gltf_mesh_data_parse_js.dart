import 'package:thermion_dart/thermion_dart.dart';

/// Web stub for [FFIGltfMeshData.parse].
///
/// The cgltf parser (GltfParser_parseBuffer) fills a TMeshData struct, whose
/// fields the WASM/js_interop bindings do not expose (structs are opaque
/// there; the pre-WASM shim's Struct.create threw UnimplementedError at
/// runtime too). parseGltf has therefore never actually run on web — this
/// stub keeps the package web-compilable and fails with a clear message
/// instead of a compile error.
Future<({Float32List vertices, Uint32List? indices, PrimitiveType primitiveType})> parseGltfMeshData(
  Uint8List data,
  String? meshName,
) async {
  throw UnsupportedError('parseGltf requires a native build; the cgltf parser is not exposed through the web bindings');
}
