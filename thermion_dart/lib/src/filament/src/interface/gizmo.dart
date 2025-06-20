import 'axis.dart';
import 'entity.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

enum GizmoPickResultType { AxisX, AxisY, AxisZ, Parent, None }

enum GizmoType { translation, rotation }

abstract class GizmoAsset extends ThermionAsset {
  Future pick(int x, int y,
      {Future Function(GizmoPickResultType axis, Vector3 coords)? handler});
  Future highlight(Axis axis);
  Future unhighlight();
  bool isNonPickable(ThermionEntity entity);
  bool isGizmoEntity(ThermionEntity entity);
    
  Future dispose();
    
}
