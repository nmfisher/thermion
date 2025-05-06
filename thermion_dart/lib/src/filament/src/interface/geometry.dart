import 'dart:typed_data';

import 'package:thermion_dart/src/bindings/bindings.dart';

import '../../../viewer/viewer.dart';

class Geometry {
  final Float32List vertices;
  final Uint16List indices;
  final Float32List? normals;
  final Float32List? uvs;
  final PrimitiveType primitiveType;

  Geometry(
    this.vertices,
    this.indices, {
    this.normals,
    this.uvs,
    this.primitiveType = PrimitiveType.TRIANGLES,
  }) {
    if(this.uvs != null && this.uvs!.length != (vertices.length ~/ 3 * 2)) {
      throw Exception("Expected either ${indices.length * 2} UVs, got ${this.uvs!.length}");
    }   
  }

  void scale(double factor) {
    for (int i = 0; i < vertices.length; i++) {
      vertices[i] = vertices[i] * factor;
    }
  }

  bool get hasNormals => normals?.isNotEmpty == true;
  bool get hasUVs => uvs?.isNotEmpty == true;
}
