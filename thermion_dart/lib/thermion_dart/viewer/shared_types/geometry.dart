import 'dart:typed_data';

import 'package:thermion_dart/thermion_dart/viewer/thermion_viewer_base.dart';

class Geometry {
  final Float32List vertices;
  final Uint16List indices;
  final Float32List normals;
  final Float32List uvs;
  final PrimitiveType primitiveType;

  Geometry(
    this.vertices,
    List<int> indices, {
    Float32List? normals,
    Float32List? uvs,
    this.primitiveType = PrimitiveType.TRIANGLES,
  })  : indices = Uint16List.fromList(indices),
        normals = normals ?? Float32List(0),
        uvs = uvs ?? Float32List(0) {
    assert(this.uvs.length == 0 || this.uvs.length == (vertices.length ~/ 3) * 2);
  }

  void scale(double factor) {
    for (int i = 0; i < vertices.length; i++) {
      vertices[i] = vertices[i] * factor;
    }
  }

  bool get hasNormals => normals.isNotEmpty;
  bool get hasUVs => uvs.isNotEmpty;
}
