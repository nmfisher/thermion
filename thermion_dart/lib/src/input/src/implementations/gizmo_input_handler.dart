import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

class _Gizmo {
  bool isVisible = false;

  final ThermionViewer viewer;
  final GizmoAsset _gizmo;

  ThermionEntity? _attachedTo;

  _Gizmo(this._gizmo, this.viewer);

  final _onEntityTransformUpdated = StreamController<
      ({ThermionEntity entity, Matrix4 transform})>.broadcast();

  Axis? _active;
  Axis? get active => _active;

  Vector3? _activeCords;

  void checkHover(int x, int y) async {
    _gizmo.pick(x, y, handler: (result, coords) async {
      switch (result) {
        case GizmoPickResultType.None:
          await _gizmo.unhighlight();
          _active = null;
          break;
        case GizmoPickResultType.AxisX:
          _active = Axis.X;
          _activeCords = coords;

        case GizmoPickResultType.AxisY:
          _active = Axis.Y;
          _activeCords = coords;

        case GizmoPickResultType.AxisZ:
          _active = Axis.Z;
          _activeCords = coords;

        default:
      }
    });
  }

  Matrix4? gizmoTransform;

  Future attach(ThermionEntity entity) async {
    print("Attached to ${entity}");

    if (_attachedTo != null && entity != _attachedTo) {
      await viewer.setParent(_attachedTo!, 0);
    }

    _attachedTo = entity;

    await viewer.setParent(_gizmo.entity, entity);
    await viewer.setTransform(_gizmo.entity, Matrix4.identity());

    if (!isVisible) {
      await _gizmo.addToScene();
      isVisible = true;
    }
    gizmoTransform = await viewer.getWorldTransform(entity);
  }

  Future detach() async {
    await _gizmo.removeFromScene();
    if (_attachedTo != null) {
      await viewer.setParent(_attachedTo!, 0);
    }
    _active = null;
    isVisible = false;
  }

  void _updateTransform(Vector2 currentPosition, Vector2 delta) async {
    if (_attachedTo == null) {
      return;
    }

    var view = await viewer.getViewAt(0);
    var camera = await viewer.getActiveCamera();

    var viewport = await view.getViewport();

    var projectionMatrix = await viewer.getCameraProjectionMatrix();
    var viewMatrix = await camera.getViewMatrix();
    var inverseViewMatrix = await camera.getModelMatrix();
    var inverseProjectionMatrix = projectionMatrix.clone()..invert();

    // get gizmo position in screenspace
    var gizmoPositionWorldSpace = gizmoTransform!.getTranslation();
    Vector4 gizmoClipSpace = projectionMatrix *
        viewMatrix *
        Vector4(gizmoPositionWorldSpace.x, gizmoPositionWorldSpace.y,
            gizmoPositionWorldSpace.z, 1.0);

    var gizmoNdc = gizmoClipSpace / gizmoClipSpace.w;

    var gizmoScreenSpace = Vector2(((gizmoNdc.x / 2) + 0.5) * viewport.width,
        viewport.height - (((gizmoNdc.y / 2) + 0.5) * viewport.height));

    gizmoScreenSpace += delta;

    gizmoNdc = Vector4(((gizmoScreenSpace.x / viewport.width) - 0.5) * 2,
        (((gizmoScreenSpace.y / viewport.height)) - 0.5) * -2, gizmoNdc.z, 1.0);

    var gizmoViewSpace = inverseProjectionMatrix * gizmoNdc;
    gizmoViewSpace /= gizmoViewSpace.w;

    var newPosition = (inverseViewMatrix * gizmoViewSpace).xyz;

    Vector3 worldSpaceDelta = newPosition - gizmoTransform!.getTranslation();
    worldSpaceDelta.multiply(_active!.asVector());

    gizmoTransform!
        .setTranslation(gizmoTransform!.getTranslation() + worldSpaceDelta);

    await viewer.setTransform(_attachedTo!, gizmoTransform!);

    _onEntityTransformUpdated
        .add((entity: _attachedTo!, transform: gizmoTransform!));
  }
}

class GizmoInputHandler extends InputHandler {
  final InputHandler wrapped;
  final ThermionViewer viewer;
  late final _Gizmo translationGizmo;

  Stream<({ThermionEntity entity, Matrix4 transform})>
      get onEntityTransformUpdated =>
          translationGizmo._onEntityTransformUpdated.stream;

  GizmoInputHandler({required this.wrapped, required this.viewer}) {
    initialize();
  }

  final _initialized = Completer<bool>();

  Future initialize() async {
    if (_initialized.isCompleted) {
      throw Exception("Already initialized");
    }
    await viewer.initialized;
    final view = await viewer.getViewAt(0);
    var translationGizmoAsset =
        await viewer.createGizmo(view, GizmoType.translation);
    this.translationGizmo = _Gizmo(translationGizmoAsset, viewer);
    _initialized.complete(true);
  }

  @override
  Stream get cameraUpdated => throw UnimplementedError();

  @override
  Future dispose() async {
    await viewer.removeEntity(translationGizmo._gizmo);
  }

  @override
  InputAction? getActionForType(InputType gestureType) {
    if (gestureType == InputType.LMB_DOWN) {
      return InputAction.PICK;
    }
    throw UnimplementedError();
  }

  @override
  Future<bool> get initialized => _initialized.future;

  @override
  void keyDown(PhysicalKey key) {
    wrapped.keyDown(key);
  }

  @override
  void keyUp(PhysicalKey key) {
    wrapped.keyDown(key);
  }

  @override
  Future<void> onPointerDown(Vector2 localPosition, bool isMiddle) async {
    if (!_initialized.isCompleted) {
      return;
    }

    if (isMiddle) {
      return;
    }

    await viewer.pick(localPosition.x.toInt(), localPosition.y.toInt(),
        (result) async {
      if (translationGizmo._gizmo.isNonPickable(result.entity) ||
          result.entity == FILAMENT_ENTITY_NULL) {
        await translationGizmo.detach();
        return;
      }
      if (!translationGizmo._gizmo.isGizmoEntity(result.entity)) {
        translationGizmo.attach(result.entity);
      }
    });
  }

  @override
  Future<void> onPointerHover(Vector2 localPosition, Vector2 delta) async {
    if (!_initialized.isCompleted) {
      return;
    }
    translationGizmo.checkHover(
        localPosition.x.floor(), localPosition.y.floor());
  }

  @override
  Future<void> onPointerMove(
      Vector2 localPosition, Vector2 delta, bool isMiddle) async {
    if (!isMiddle && translationGizmo._active != null) {
      final scaledDelta = Vector2(
        delta.x,
        delta.y,
      );
      translationGizmo._updateTransform(localPosition, scaledDelta);
      return;
    }
    return wrapped.onPointerMove(localPosition, delta, isMiddle);
  }

  @override
  Future<void> onPointerScroll(
      Vector2 localPosition, double scrollDelta) async {
    return wrapped.onPointerScroll(localPosition, scrollDelta);
  }

  @override
  Future<void> onPointerUp(bool isMiddle) async {
    await wrapped.onPointerUp(isMiddle);
  }

  @override
  Future<void> onScaleEnd(int pointerCount, double velocity) {
    return wrapped.onScaleEnd(pointerCount, velocity);
  }

  @override
  Future<void> onScaleStart(
      Vector2 focalPoint, int pointerCount, Duration? sourceTimestamp) {
    return wrapped.onScaleStart(focalPoint, pointerCount, sourceTimestamp);
  }

  @override
  Future<void> onScaleUpdate(
      Vector2 focalPoint,
      Vector2 focalPointDelta,
      double horizontalScale,
      double verticalScale,
      double scale,
      int pointerCount,
      double rotation,
      Duration? sourceTimestamp) {
    return wrapped.onScaleUpdate(focalPoint, focalPointDelta, horizontalScale,
        verticalScale, scale, pointerCount, rotation, sourceTimestamp);
  }

  @override
  void setActionForType(InputType gestureType, InputAction gestureAction) {
    throw UnimplementedError();
  }

  Future detach(ThermionAsset asset) async {
    
    if (translationGizmo._attachedTo == asset.entity) {
      await translationGizmo.detach();
      return;
    }
    final childEntities = await asset.getChildEntities();
    for(final childEntity in childEntities) {
      if(translationGizmo._attachedTo == childEntity) {
        await translationGizmo.detach();
      return;
      }
    }
     
  }
  
  // @override
  // Future setCamera(Camera camera) async  {
  //   await wrapped.setCamera(camera);
  // }
}
