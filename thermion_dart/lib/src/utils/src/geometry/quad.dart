import 'package:thermion_dart/thermion_dart.dart';

class QuadGeometry {
  static Geometry fullscreenQuad() {
    final vertices =
        Float32List.fromList([-1.0, -1.0, 1.0, 3.0, -1.0, 1.0, -1.0, 3.0, 1.0]);
    final indices = Uint16List.fromList([0, 1, 2]);
    return Geometry(vertices, indices);
  }

  static Geometry quad() {
    final vertices = Float32List.fromList([
      -1,
      -1,
      1,
      1,
      -1,
      1,
      1,
      1,
      1,
      -1,
      1,
      1,
    ]);
    final indices = Uint16List.fromList([
      0,
      1,
      2,
      0,
      2,
      3,
    ]);
    final uvs = Float32List.fromList([
      0,
      1,
      1,
      1,
      1,
      0,
      0,
      0,
    ]);
    return Geometry(vertices, indices, uvs: uvs);
  }
}
