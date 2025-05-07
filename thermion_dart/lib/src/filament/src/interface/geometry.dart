import 'dart:typed_data';

import 'package:thermion_dart/src/bindings/bindings.dart';

import '../../../viewer/viewer.dart';

class Geometry {
  final Float32List vertices;
  final Uint16List indices;
  late final Float32List normals;
  late final Float32List uvs;
  final PrimitiveType primitiveType;

  Geometry(
    this.vertices,
    this.indices, {
    Float32List? normals,
    Float32List? uvs,
    this.primitiveType = PrimitiveType.TRIANGLES,
  }) {
    this.uvs = uvs ?? Float32List(0);
    this.normals = normals ?? Float32List(0);
    if (this.uvs.length != 0 && this.uvs.length != (vertices.length ~/ 3 * 2)) {
      throw Exception(
          "Expected either ${indices.length * 2} UVs, got ${this.uvs!.length}");
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
