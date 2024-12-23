import 'dart:async';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

class _Gizmo {
  final ThermionViewer viewer;

  final GizmoAsset _gizmo;

  final transformUpdates = StreamController<({Matrix4 transform})>.broadcast();

  Axis? _active;
  final GizmoType type;

  _Gizmo(this._gizmo, this.viewer, this.type);

  static Future<_Gizmo> forType(ThermionViewer viewer, GizmoType type) async {
    final view = await viewer.getViewAt(0);
    return _Gizmo(await viewer.createGizmo(view, type), viewer, type);
  }

  Future dispose() async {
    await transformUpdates.close();
    await viewer.removeAsset(_gizmo);
  }

  Future hide() async {
    await _gizmo.removeFromScene();
  }

  Future reveal() async {
    await _gizmo.addToScene();
    gizmoTransform = await viewer.getWorldTransform(_gizmo.entity);
  }

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

  void _updateTransform(Vector2 currentPosition, Vector2 delta) async {
    if (type == GizmoType.translation) {
      await _updateTranslation(currentPosition, delta);
    } else if (type == GizmoType.rotation) {
      await _updateRotation(currentPosition, delta);
    }

    await viewer.setTransform(_gizmo.entity, gizmoTransform!);

    transformUpdates.add((transform: gizmoTransform!));
  }

  Future<void>? _updateTranslation(
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
  }

  Future<void>? _updateRotation(Vector2 currentPosition, Vector2 delta) async {
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
  }
}

class GizmoInputHandler extends InputHandler {

  final ThermionViewer viewer;

  late final _gizmos = <GizmoType, _Gizmo>{};

  _Gizmo? _active;

  ThermionEntity? _attached;

  Future attach(ThermionEntity entity) async {
    if (_attached != null) {
      await detach();
    }
    _attached = entity;
    if (_active != null) {
      await viewer.setParent(_attached!, _active!._gizmo.entity);
      await _active!.reveal();
    }
  }

  Future<Matrix4?> getGizmoTransform() async {
    return _active?.gizmoTransform;
  }

  Future detach() async {
    if (_attached == null) {
      return;
    }
    await viewer.setParent(_attached!, 0);
    await _active?.hide();
    _attached = null;
  }

  final _initialized = Completer<bool>();

  final _transformController = StreamController<Matrix4>.broadcast();
  Stream<Matrix4> get transformUpdated => _transformController.stream;

  final _pickResultController = StreamController<ThermionEntity?>.broadcast();
  Stream<ThermionEntity?> get onPickResult => _pickResultController.stream;

  GizmoInputHandler({required this.viewer, required GizmoType initialType}) {
    initialize().then((_) {
      setGizmoType(initialType);
    });
  }

  GizmoType? getGizmoType() {
    return _active?.type;
  }

  Future setGizmoType(GizmoType? type) async {
    if (type == null) {
      await detach();
      _active?.hide();
      _active = null;
    } else {
      _active?.hide();
      _active = _gizmos[type]!;
      _active!.reveal();
      if (_attached != null) {
        await attach(_attached!);
      }
    }
  }

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
    for (final gizmo in _gizmos.values) {
      gizmo.transformUpdates.stream.listen((update) {
        _transformController.add(update.transform);
      });
    }
    _initialized.complete(true);
  }

  @override
  Future dispose() async {
    _gizmos[GizmoType.rotation]!.dispose();
    _gizmos[GizmoType.translation]!.dispose();
    _gizmos.clear();
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
  void keyDown(PhysicalKey key) {}

  @override
  void keyUp(PhysicalKey key) {}

  @override
  Future<void>? onPointerDown(Vector2 localPosition, bool isMiddle) async {
    if (!_initialized.isCompleted) {
      return;
    }

    if (isMiddle) {
      return;
    }

    await viewer.pick(localPosition.x.toInt(), localPosition.y.toInt(),
        (result) async {
      if (_active?._gizmo.isNonPickable(result.entity) == true ||
          result.entity == FILAMENT_ENTITY_NULL) {
        _pickResultController.add(null);
        return;
      }
      if (_active?._gizmo.isGizmoEntity(result.entity) != true) {
        _pickResultController.add(result.entity);
      }
    });
  }

  @override
  Future<void>? onPointerHover(Vector2 localPosition, Vector2 delta) async {
    if (!_initialized.isCompleted) {
      return;
    }
    _active?.checkHover(localPosition.x.floor(), localPosition.y.floor());
  }

  @override
  Future<void>? onPointerMove(
      Vector2 localPosition, Vector2 delta, bool isMiddle) async {
    if (!isMiddle && _active?._active != null) {
      final scaledDelta = Vector2(
        delta.x,
        delta.y,
      );
      _active!._updateTransform(localPosition, scaledDelta);
      return;
    }
  }

  @override
  Future<void>? onPointerScroll(
      Vector2 localPosition, double scrollDelta) async {}

  @override
  Future<void>? onPointerUp(bool isMiddle) async {}

  @override
  Future<void>? onScaleEnd(int pointerCount, double velocity) {}

  @override
  Future<void>? onScaleStart(
      Vector2 focalPoint, int pointerCount, Duration? sourceTimestamp) {}

  @override
  Future<void>? onScaleUpdate(
      Vector2 focalPoint,
      Vector2 focalPointDelta,
      double horizontalScale,
      double verticalScale,
      double scale,
      int pointerCount,
      double rotation,
      Duration? sourceTimestamp) {}

  @override
  void setActionForType(InputType gestureType, InputAction gestureAction) {
    throw UnimplementedError();
  }
}
