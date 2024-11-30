import 'dart:async';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/entities.dart';
import 'thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ffi_view.dart';

class FFIGizmo extends FFIAsset implements GizmoAsset {
  final Set<ThermionEntity> gizmoEntities;
  late NativeCallable<GizmoPickCallbackFunction> _nativeCallback;

  void Function(GizmoPickResultType axis, Vector3 coords)? _callback;

  late FFIView _view;

  void _onPickResult(int resultType, double x, double y, double z) {
    _callback?.call(GizmoPickResultType.values[resultType], Vector3(x, y, z));
  }

  bool isNonPickable(ThermionEntity entity) {
    return SceneManager_isGridEntity(sceneManager!, entity);
  }

  bool isGizmoEntity(ThermionEntity entity) => gizmoEntities.contains(entity);

  FFIGizmo(
      this._view,
      super.pointer,
      super.sceneManager,
      super.renderableManager,
      super.unlitMaterialProvider,
      this.gizmoEntities) {
    _nativeCallback =
        NativeCallable<GizmoPickCallbackFunction>.listener(_onPickResult);
  }

  @override
  Future removeStencilHighlight() async {
    throw Exception("Not supported for gizmo");
  }

  @override
  Future setStencilHighlight(
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entityIndex}) async {
    throw Exception("Not supported for gizmo");
  }

  @override
  Future pick(int x, int y,
      {Future Function(GizmoPickResultType result, Vector3 coords)?
          handler}) async {
    _callback = handler;
    final viewport = await _view.getViewport();
    y = viewport.height - y;

    Gizmo_pick(pointer.cast<TGizmo>(), x, y, _nativeCallback.nativeFunction);
  }

  @override
  Future highlight(Axis axis) async {
    Gizmo_unhighlight(pointer.cast<TGizmo>());
    Gizmo_highlight(pointer.cast<TGizmo>(), TGizmoAxis.values[axis.index]);
  }

  @override
  Future unhighlight() async {
    Gizmo_unhighlight(pointer.cast<TGizmo>());
  }
}
