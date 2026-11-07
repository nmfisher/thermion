import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';
import 'ffi_material.dart';

class FFIGizmo extends GizmoAsset {
  final Set<ThermionEntity> entities;

  late final CallbackHolder<GizmoPickCallbackFunction> _callbackHolder;

  void Function(GizmoPickResultType axis, Vector3 coords)? _callback;

  final View view;

  final Pointer<TGizmo> handle;

  final FFIFilamentApp app;

  FFIGizmo({required this.handle, required this.view, required this.entities, required FFIFilamentApp app}) : app = app {
    _callbackHolder = _onPickResult.asCallback();
  }

  Future dispose() async {
    _callbackHolder.dispose();
  }

  static FFIMaterial? _gizmoMaterial;

  static Future<GizmoAsset> create(FFIFilamentApp app, View view, GizmoType gizmoType) async {
    final engine = app.engine;
    if (_gizmoMaterial == null) {
      final materialPtr = await withPointerCallback<TMaterial>((cb) {
        Material_createGizmoMaterialJobThread(app.jobThreadHandle, engine, cb);
      });
      _gizmoMaterial ??= FFIMaterial(materialPtr, app);
    }

    var gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
      (cb) => GltfResourceLoader_createJobThread(app.jobThreadHandle, engine, cb),
    );

    final gizmo = await withPointerCallback<TGizmo>((cb) {
      Gizmo_createJobThread(
        app.jobThreadHandle,
        engine,
        app.gltfAssetLoader,
        gltfResourceLoader,
        nullptr,
        view.getNativeHandle(),
        _gizmoMaterial!.pointer,
        gizmoType.index,
        cb,
      );
    });
    if (gizmo == nullptr) {
      throw Exception("Failed to create gizmo");
    }
    final gizmoEntityCount = SceneAsset_getChildEntityCount(gizmo.cast<TSceneAsset>());
    final gizmoEntities = Int32List(gizmoEntityCount);
    SceneAsset_getChildEntities(gizmo.cast<TSceneAsset>(), gizmoEntities.address);

    final gizmoAsset = FFIGizmo(
      handle: gizmo,
      view: view,
      app: app,
      entities: gizmoEntities.toSet()..add(SceneAsset_getEntity(gizmo.cast<TSceneAsset>())),
    );
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      gizmoEntities.free();
    }

    return gizmoAsset;
  }

  void _onPickResult(int resultType, double x, double y, double z) {
    final type = switch (resultType) {
      TGizmoPickResultType.AxisX => GizmoPickResultType.AxisX,
      TGizmoPickResultType.AxisY => GizmoPickResultType.AxisY,
      TGizmoPickResultType.AxisZ => GizmoPickResultType.AxisZ,
      TGizmoPickResultType.None => GizmoPickResultType.None,
      TGizmoPickResultType.Parent => GizmoPickResultType.Parent,
      _ => throw UnsupportedError(resultType.toString()),
    };
    _callback?.call(type, Vector3(x, y, z));
  }

  bool isNonPickable(ThermionEntity entity) {
    throw UnimplementedError();
    // return SceneManager_isGridEntity(sceneManager, entity);
  }

  bool isGizmoEntity(ThermionEntity entity) => entities.contains(entity);

  @override
  Future pick(int x, int y, {Future Function(GizmoPickResultType result, Vector3 coords)? handler}) async {
    _callback = handler;
    final viewport = await view.getViewport();
    y = viewport.height - y;

    if (FILAMENT_WASM) {
      // Web worker: the pick (View::pick + the gizmo entity-to-axis mapping)
      // must run on the job thread, which is the worker that renders. Calling
      // the direct export from the Dart thread links a picking query into the
      // list the render job is reading (FrameGraph::assertValid abort). The
      // pick-result callback is the completion; there is nothing to await.
      Gizmo_pickJobThread(app.jobThreadHandle, handle, x, y, _callbackHolder.pointer);
    } else {
      // Native: the direct export is serialised against the job thread by the
      // engine API lock and keeps its synchronous semantics.
      Gizmo_pick(handle, x, y, _callbackHolder.pointer);
    }
  }

  @override
  Future highlight(Axis axis) async {
    Gizmo_unhighlight(handle);
    final tAxis = switch (axis) {
      Axis.X => TGizmoAxis.X,
      Axis.Y => TGizmoAxis.Y,
      Axis.Z => TGizmoAxis.Z,
    };
    Gizmo_highlight(handle, tAxis);
  }

  @override
  Future unhighlight() async {
    Gizmo_unhighlight(handle);
  }
}
