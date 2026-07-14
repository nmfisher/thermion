import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';

class Geometry {
  late final _logger = Logger(this.runtimeType.toString());
  final Float32List vertices;
  final List<int> indices;
  final IndexType indexType;
  late final Float32List normals;
  late final Float32List uvs;
  late final Float32List uvs1;
  late final Float32List colors;
  late final Float32List attribute0;
  final PrimitiveType primitiveType;

  // Vertex colors and/or UVs aren't required for basic geometry renderables.
  // However, ubershader materials will fail to be applied if these buffers are
  // not allocated. This can lead to unexpected behaviour (particulary when using
  // FilamentApp.instance.createUnlitMaterialInstance(), which requests an unlit
  // ubershader material instance.
  //
  // To avoid unexpected behaviour, [createDummyColors] and [createDummyUvs]
  // both default to [true], meaning dummy values will be created for each
  // vertex ((1,1,1,1) for vertex color, (0,0) for vertex UV) if [colors] and/or
  // [uvs] is null.
  //
  // The ubershader requires two UV sets (UV0 and UV1). If [createDummyUvs1] is
  // true (default), UV1 will be created as a copy of UV0 if not provided.
  //
  Geometry(
    this.vertices,
    this.indices, {
    Float32List? normals,
    Float32List? uvs,
    Float32List? uvs1,
    Float32List? colors,
    Float32List? attribute0,
    this.primitiveType = PrimitiveType.TRIANGLES,
    this.indexType = IndexType.UINT,
    bool createDummyColors = true,
    bool createDummyUvs = true,
    bool createDummyUvs1 = true,
  }) {
    this.attribute0 = attribute0 ?? Float32List(0);
    this.uvs = uvs ?? Float32List(0);
    this.normals = normals ?? Float32List(0);

    if (colors == null) {
      if (createDummyColors) {
        colors = makeFloat32List(vertices.length ~/ 3 * 4);
        colors.fillRange(0, colors.length, 1);
        _logger.info("Created dummy colors");
      } else {
        colors = makeFloat32List(0);
      }
    }
    this.colors = colors;
    if (this.colors.length != 0 &&
        this.colors.length != (vertices.length ~/ 3 * 4)) {
      throw Exception(
        "Expected ${vertices.length ~/ 3 * 4} color values (RGBA), got ${this.colors.length}",
      );
    }

    if (uvs == null) {
      if (createDummyUvs) {
        uvs = makeFloat32List(vertices.length ~/ 3 * 2);
        uvs.fillRange(0, uvs.length, 0.0);
      } else {
        uvs = makeFloat32List(0);
      }
    }

    final numVertices = vertices.length ~/ 3;
    final expectedUvs = numVertices * 2;
    if (hasUVs && this.uvs.length != expectedUvs) {
      throw Exception("Expected ${expectedUvs} UVs, got ${this.uvs!.length}");
    }

    // Handle UV1 - ubershader requires two UV sets
    if (uvs1 == null) {
      if (createDummyUvs1) {
        // Copy UV0 to UV1 if UV0 exists, otherwise create zeros
        if (this.uvs.isNotEmpty) {
          this.uvs1 = Float32List.fromList(this.uvs);
        } else {
          this.uvs1 = makeFloat32List(vertices.length ~/ 3 * 2);
          this.uvs1.fillRange(0, this.uvs1.length, 0.0);
        }
      } else {
        this.uvs1 = makeFloat32List(0);
      }
    } else {
      this.uvs1 = uvs1;
    }

    if (hasUVs1 && this.uvs1.length != expectedUvs) {
      throw Exception("Expected ${expectedUvs} UV1s, got ${this.uvs1.length}");
    }

    if (hasAttribute0 &&
        this.attribute0.length != (this.vertices.length ~/ 3 * 4)) {
      throw Exception(
        "Expected ${indices.length * 4} ATTRIBUTE0, got ${this.attribute0.length}",
      );
    }
  }

  void scale(double factor) {
    for (int i = 0; i < vertices.length; i++) {
      vertices[i] = vertices[i] * factor;
    }
  }

  bool get hasNormals => normals.isNotEmpty == true;
  bool get hasUVs => uvs.isNotEmpty == true;
  bool get hasUVs1 => uvs1.isNotEmpty == true;
  bool get hasColors => colors.isNotEmpty == true;
  bool get hasAttribute0 => attribute0.isNotEmpty == true;

  void dispose() {
    vertices.free();
    normals.free();
    uvs.free();
    uvs1.free();
    colors.free();
  }
}
