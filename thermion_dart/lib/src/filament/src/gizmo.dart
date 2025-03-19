import 'entity.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

enum Axis {
  X(const [1.0, 0.0, 0.0]),
  Y(const [0.0, 1.0, 0.0]),
  Z(const [0.0, 0.0, 1.0]);

  const Axis(this.vector);

  final List<double> vector;

  Vector3 asVector() => Vector3(vector[0], vector[1], vector[2]);
}

enum GizmoPickResultType { AxisX, AxisY, AxisZ, Parent, None }

enum GizmoType { translation, rotation }

abstract class GizmoAsset extends ThermionAsset {
  Future pick(int x, int y,
      {Future Function(GizmoPickResultType axis, Vector3 coords)? handler});
  Future highlight(Axis axis);
  Future unhighlight();
  bool isNonPickable(ThermionEntity entity);
  bool isGizmoEntity(ThermionEntity entity);
}
