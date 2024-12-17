import 'dart:async';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

class _Gizmo {
  bool isVisible = false;
  final ThermionViewer viewer;
  final GizmoAsset _gizmo;
  ThermionEntity? _attachedTo;

  final attachedTo = StreamController<ThermionEntity?>.broadcast();

  final GizmoType _gizmoType;

  _Gizmo(this._gizmo, this.viewer, this._gizmoType);

  static Future<_Gizmo> forType(ThermionViewer viewer, GizmoType type) async {
    final view = await viewer.getViewAt(0);
    return _Gizmo(await viewer.createGizmo(view, type), viewer, type);
  }

  final _onEntityTransformUpdated = StreamController<
      ({ThermionEntity entity, Matrix4 transform})>.broadcast();

  Axis? _active;
  Axis? get active => _active;

  double _getAngleBetweenVectors(Vector2 v1, Vector2 v2) {
    // Normalize vectors to ensure consistent rotation regardless of distance from center
    v1.normalize();
    v2.normalize();

    // Calculate angle using atan2
    double angle = atan2(v2.y, v2.x) - atan2(v1.y, v1.x);

    // Ensure angle is between -π and π
    if (angle > pi) angle -= 2 * pi;
    if (angle < -pi) angle += 2 * pi;

    return angle;
  }

  void checkHover(int x, int y) async {
    _gizmo.pick(x, y, handler: (result, coords) async {
      switch (result) {
        case GizmoPickResultType.None:
          await _gizmo.unhighlight();
          _active = null;
          break;
        case GizmoPickResultType.AxisX:
          _active = Axis.X;
        case GizmoPickResultType.AxisY:
          _active = Axis.Y;
        case GizmoPickResultType.AxisZ:
          _active = Axis.Z;
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
    attachedTo.add(_attachedTo);

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
    attachedTo.add(null);
    _active = null;
    isVisible = false;
  }

  void _updateTransform(Vector2 currentPosition, Vector2 delta) async {
    if (_attachedTo == null) {
      return;
    }

    if (_gizmoType == GizmoType.translation) {
      await _updateTranslation(currentPosition, delta);
    } else if (_gizmoType == GizmoType.rotation) {
      await _updateRotation(currentPosition, delta);
    }

    _onEntityTransformUpdated
        .add((entity: _attachedTo!, transform: gizmoTransform!));
  }

  Future<void> _updateTranslation(
      Vector2 currentPosition, Vector2 delta) async {
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
  }

  Future<void> _updateRotation(Vector2 currentPosition, Vector2 delta) async {
    var view = await viewer.getViewAt(0);
    var camera = await viewer.getActiveCamera();
    var viewport = await view.getViewport();
    var projectionMatrix = await viewer.getCameraProjectionMatrix();
    var viewMatrix = await camera.getViewMatrix();

    // Get gizmo center in screen space
    var gizmoPositionWorldSpace = gizmoTransform!.getTranslation();
    Vector4 gizmoClipSpace = projectionMatrix *
        viewMatrix *
        Vector4(gizmoPositionWorldSpace.x, gizmoPositionWorldSpace.y,
            gizmoPositionWorldSpace.z, 1.0);

    var gizmoNdc = gizmoClipSpace / gizmoClipSpace.w;
    var gizmoScreenSpace = Vector2(((gizmoNdc.x / 2) + 0.5) * viewport.width,
        viewport.height - (((gizmoNdc.y / 2) + 0.5) * viewport.height));

    // Calculate vectors from gizmo center to previous and current mouse positions
    var prevVector = (currentPosition - delta) - gizmoScreenSpace;
    var currentVector = currentPosition - gizmoScreenSpace;

    // Calculate rotation angle based on the active axis
    double rotationAngle = 0.0;
    switch (_active) {
      case Axis.X:
        // For X axis, project onto YZ plane
        var prev = Vector2(prevVector.y, -prevVector.x);
        var curr = Vector2(currentVector.y, -currentVector.x);
        rotationAngle = _getAngleBetweenVectors(prev, curr);
        break;
      case Axis.Y:
        // For Y axis, project onto XZ plane
        var prev = Vector2(prevVector.x, -prevVector.y);
        var curr = Vector2(currentVector.x, -currentVector.y);
        rotationAngle = _getAngleBetweenVectors(prev, curr);
        break;
      case Axis.Z:
        // For Z axis, use screen plane directly
        rotationAngle = -1 * _getAngleBetweenVectors(prevVector, currentVector);
        break;
      default:
        return;
    }

    // Create rotation matrix based on the active axis
    var rotationMatrix = Matrix4.identity();
    switch (_active) {
      case Axis.X:
        rotationMatrix.setRotationX(rotationAngle);
        break;
      case Axis.Y:
        rotationMatrix.setRotationY(rotationAngle);
        break;
      case Axis.Z:
        rotationMatrix.setRotationZ(rotationAngle);
        break;
      default:
        return;
    }

    // Apply rotation to the current transform
    gizmoTransform = gizmoTransform! * rotationMatrix;
    await viewer.setTransform(_attachedTo!, gizmoTransform!);
  }
}

class GizmoInputHandler extends InputHandler {
  final InputHandler wrapped;

  final ThermionViewer viewer;

  late final _gizmos = <GizmoType, _Gizmo>{};

  _Gizmo? active;

  StreamSubscription? _entityTransformUpdatedListener;
  StreamSubscription? _attachedToListener;

  final _attachedTo = StreamController<ThermionEntity?>.broadcast();
  Stream<ThermionEntity?> get attachedTo => _attachedTo.stream;

  GizmoType? getGizmoType() {
    return active?._gizmoType;
  }

  Future setGizmoType(GizmoType? type) async {
    if (type == null) {
      await active?.detach();
      active = null;
      return;
    }

    var target = _gizmos[type]!;
    if (target != active) {
      await _entityTransformUpdatedListener?.cancel();
      await _attachedToListener?.cancel();
      if (active?._attachedTo != null) {
        var attachedTo = active!._attachedTo!;
        await active!.detach();
        await target.attach(attachedTo);
      }
      active = target;
      _entityTransformUpdatedListener =
          active!._onEntityTransformUpdated.stream.listen((event) {
        _transformUpdatedController.add(event);
      });

      _attachedToListener = active!.attachedTo.stream.listen((entity) {
        _attachedTo.add(entity);
      });
    }
  }

  final _transformUpdatedController =
      StreamController<({ThermionEntity entity, Matrix4 transform})>();
  Stream<({ThermionEntity entity, Matrix4 transform})>
      get onEntityTransformUpdated => _transformUpdatedController.stream;

  GizmoInputHandler({required this.wrapped, required this.viewer}) {
    initialize();
  }

  final _initialized = Completer<bool>();

  Future initialize() async {
    if (_initialized.isCompleted) {
      throw Exception("Already initialized");
    }
    await viewer.initialized;

    _gizmos[GizmoType.translation] =
        await _Gizmo.forType(viewer, GizmoType.translation);
    _gizmos[GizmoType.rotation] =
        await _Gizmo.forType(viewer, GizmoType.rotation);
    await setGizmoType(GizmoType.translation);
    _initialized.complete(true);
  }

  @override
  Stream get cameraUpdated => throw UnimplementedError();

  @override
  Future dispose() async {
    await viewer.removeEntity(_gizmos[GizmoType.rotation]!._gizmo);
    await viewer.removeEntity(_gizmos[GizmoType.translation]!._gizmo);
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
      if (active?._gizmo.isNonPickable(result.entity) == true ||
          result.entity == FILAMENT_ENTITY_NULL) {
        await active!.detach();
        return;
      }
      if (active?._gizmo.isGizmoEntity(result.entity) != true) {
        active!.attach(result.entity);
      }
    });
  }

  @override
  Future<void> onPointerHover(Vector2 localPosition, Vector2 delta) async {
    if (!_initialized.isCompleted) {
      return;
    }
    active?.checkHover(localPosition.x.floor(), localPosition.y.floor());
  }

  @override
  Future<void> onPointerMove(
      Vector2 localPosition, Vector2 delta, bool isMiddle) async {
    if (!isMiddle && active?._active != null) {
      final scaledDelta = Vector2(
        delta.x,
        delta.y,
      );
      active!._updateTransform(localPosition, scaledDelta);
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
    if (active?._attachedTo == asset.entity) {
      await active!.detach();
      return;
    }
    final childEntities = await asset.getChildEntities();
    for (final childEntity in childEntities) {
      if (active?._attachedTo == childEntity) {
        await active!.detach();
        return;
      }
    }
  }
}
