import 'package:thermion_dart/thermion_dart.dart';

class Geometry {
  final Float32List vertices;
  final List<int> indices;
  final IndexType indexType;
  late final Float32List normals;
  late final Float32List uvs;
  late final Float32List colors;
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
  Geometry(
    this.vertices,
    this.indices, {
    Float32List? normals,
    Float32List? uvs,
    Float32List? colors,
    this.primitiveType = PrimitiveType.TRIANGLES,
    this.indexType = IndexType.UINT,
    bool createDummyColors = true,
    bool createDummyUvs = true,
  }) {
    this.uvs = uvs ?? Float32List(0);
    this.normals = normals ?? Float32List(0);

    if (colors == null) {
      if (createDummyColors) {
        colors = makeFloat32List(vertices.length ~/ 3 * 4);
        colors.fillRange(0, colors.length, 1);
      } else {
        colors = makeFloat32List(0);
      }
    }
    this.colors = colors;
    if (this.colors.length != 0 &&
        this.colors.length != (vertices.length ~/ 3 * 4)) {
      throw Exception(
          "Expected ${vertices.length ~/ 3 * 4} color values (RGBA), got ${this.colors.length}");
    }

    if (uvs == null) {
      if (createDummyUvs) {
        uvs = makeFloat32List(vertices.length ~/ 3 * 2);
        uvs.fillRange(0, uvs.length, 0.0);
      } else {
        uvs = makeFloat32List(0);
      }
    }

    if (this.uvs.length != 0 && this.uvs.length != (vertices.length ~/ 3 * 2)) {
      throw Exception(
          "Expected ${indices.length * 2} UVs, got ${this.uvs!.length}");
    }
  }

  void scale(double factor) {
    for (int i = 0; i < vertices.length; i++) {
      vertices[i] = vertices[i] * factor;
    }
  }

  bool get hasNormals => normals?.isNotEmpty == true;
  bool get hasUVs => uvs?.isNotEmpty == true;
  bool get hasColors => colors?.isNotEmpty == true;

  void dispose() {
    vertices.free();
    normals.free();
    uvs.free();
    colors.free();
  }
}
