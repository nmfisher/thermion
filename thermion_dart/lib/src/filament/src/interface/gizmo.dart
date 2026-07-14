import 'package:thermion_dart/thermion_dart.dart';

enum GizmoPickResultType { AxisX, AxisY, AxisZ, Parent, None }

enum GizmoType { translation, rotation }

abstract class GizmoAsset {
  Future pick(
    int x,
    int y, {
    Future Function(GizmoPickResultType axis, Vector3 coords)? handler,
  });
  Future highlight(Axis axis);
  Future unhighlight();
  bool isNonPickable(ThermionEntity entity);
  bool isGizmoEntity(ThermionEntity entity);

  Future dispose();
}
