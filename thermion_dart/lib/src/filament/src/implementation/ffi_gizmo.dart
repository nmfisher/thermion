import 'dart:async';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'ffi_view.dart';

class FFIGizmo extends FFIAsset implements GizmoAsset {
  final Set<ThermionEntity> entities;

  late final CallbackHolder<GizmoPickCallbackFunction> _callbackHolder;

  void Function(GizmoPickResultType axis, Vector3 coords)? _callback;

  late FFIView view;

    FFIGizmo(
      super.asset,
      super.app,
      super.animationManager,
      {
    required this.view,
    required this.entities,
  }) {
    
    _callbackHolder = _onPickResult.asCallback();
  }

  ///
  ///
  ///
  Future dispose() async {
    _callbackHolder.dispose();
  }

  
  void _onPickResult(int resultType, double x, double y, double z) {
    
    final type = switch(resultType) {
      TGizmoPickResultType.AxisX => GizmoPickResultType.AxisX,
      TGizmoPickResultType.AxisY => GizmoPickResultType.AxisY,
      TGizmoPickResultType.AxisZ => GizmoPickResultType.AxisZ,
      TGizmoPickResultType.None => GizmoPickResultType.None,
      TGizmoPickResultType.Parent => GizmoPickResultType.Parent,
      _ => throw UnsupportedError(resultType.toString())
    };
    _callback?.call(type, Vector3(x, y, z));
  }

  bool isNonPickable(ThermionEntity entity) {
    throw UnimplementedError();
    // return SceneManager_isGridEntity(sceneManager, entity);
  }

  bool isGizmoEntity(ThermionEntity entity) => entities.contains(entity);

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

    Gizmo_pick(asset.cast<TGizmo>(), x, y, _callbackHolder.pointer);
  }

  @override
  Future highlight(Axis axis) async {
    Gizmo_unhighlight(asset.cast<TGizmo>());
    final tAxis = switch(axis) {
      Axis.X => TGizmoAxis.X,
      Axis.Y => TGizmoAxis.Y,
      Axis.Z => TGizmoAxis.Z
    };
    Gizmo_highlight(asset.cast<TGizmo>(), tAxis);
  }

  @override
  Future unhighlight() async {
    Gizmo_unhighlight(asset.cast<TGizmo>());
  }
}
