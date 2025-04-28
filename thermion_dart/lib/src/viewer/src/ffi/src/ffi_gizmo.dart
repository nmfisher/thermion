import 'dart:async';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'ffi_view.dart';

class FFIGizmo extends FFIAsset implements GizmoAsset {
  final Set<ThermionEntity> entities;
  late NativeCallable<GizmoPickCallbackFunction> _nativeCallback;

  void Function(GizmoPickResultType axis, Vector3 coords)? _callback;

  late FFIView view;

  void _onPickResult(int resultType, double x, double y, double z) {
    _callback?.call(GizmoPickResultType.values[resultType], Vector3(x, y, z));
  }

  bool isNonPickable(ThermionEntity entity) {
    throw UnimplementedError();
    // return SceneManager_isGridEntity(sceneManager, entity);
  }

  bool isGizmoEntity(ThermionEntity entity) => entities.contains(entity);

    FFIGizmo(
      super.asset,
      super.app,
      super.animationManager,
      {
    required this.view,
    required this.entities,
  }) {
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
    final viewport = await view.getViewport();
    y = viewport.height - y;

    Gizmo_pick(asset.cast<TGizmo>(), x, y, _nativeCallback.nativeFunction);
  }

  @override
  Future highlight(Axis axis) async {
    Gizmo_unhighlight(asset.cast<TGizmo>());
    Gizmo_highlight(asset.cast<TGizmo>(), TGizmoAxis.values[axis.index]);
  }

  @override
  Future unhighlight() async {
    Gizmo_unhighlight(asset.cast<TGizmo>());
  }
}
