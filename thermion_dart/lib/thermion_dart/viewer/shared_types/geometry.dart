import 'package:thermion_dart/thermion_dart/viewer/thermion_viewer_base.dart';

class Geometry {
  final List<double> vertices;
  final List<int> indices;
  final List<double>? normals;
  final List<(double, double)>? uvs;
  final PrimitiveType primitiveType;
  final String? materialPath;

  Geometry(this.vertices, this.indices, { this.normals=null, this.uvs=null,
      this.primitiveType = PrimitiveType.TRIANGLES, this.materialPath = null});

  void scale(double factor) {
    for (int i = 0; i < vertices.length; i++) {
      vertices[i] = vertices[i] * factor;
    }
  }
}
