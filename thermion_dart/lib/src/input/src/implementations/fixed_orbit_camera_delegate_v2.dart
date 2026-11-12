import 'dart:async';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../../input.dart';

class OrbitInputHandlerDelegate extends InputHandlerDelegate {
  final View view;

  /// When provided, camera updates are coalesced and applied once per
  /// rendered frame from a request-frame hook instead of once per input
  /// event. When null (legacy direct construction), every event batch
  /// applies immediately as before.
  final FilamentApp? app;
  final InputSensitivityOptions sensitivity;
  final Vector3 targetPoint;
  final double minZoomDistance;
  final double maxZoomDistance;
  final worldUp = Vector3(0, 1, 0);

  double _radius;
  double _radiusScaleFactor = 1.0;
  double _azimuth; // Angle around worldUp (Y-axis), in radians
  double _elevation; // Angle above the XZ plane (around local X-axis), in radians

  bool _isInitialized = false;
  bool _isMouseDown = false;

  Vector2? _lastPointerPosition;

  final bool moveOnHover;

  // Deltas accumulated from input events since the last applied update.
  // Drained by [_applyPending] once per frame when [app] is set, or per
  // event batch otherwise. High-rate pointers (240-1000 Hz) would otherwise
  // trigger a camera read-modify-write per event.
  double _pendingDeltaAzimuth = 0;
  double _pendingDeltaElevation = 0;
  double _pendingDeltaRadius = 0;

  RequestFrameHook? _onFrame;

  /// Cached camera handle; [View.getCamera] returns the same underlying
  /// camera for the view's lifetime.
  Camera? _camera;

  OrbitInputHandlerDelegate(
    this.view, {
    this.app,
    this.sensitivity = const InputSensitivityOptions(),
    Vector3? targetPoint,
    this.minZoomDistance = 1.0,
    this.maxZoomDistance = 100.0,
    this.moveOnHover = false,
  }) : targetPoint = targetPoint ?? Vector3.zero(),
       _radius = (minZoomDistance + maxZoomDistance) / 2, // Initial default radius
       _azimuth = 0.0,
       _elevation = math.pi / 4 {
    if (app != null) {
      _onFrame = (int frameTimeNanos, Duration delta) => _applyPending();
      app!.registerRequestFrameHook(_onFrame!);
    }
  }

  Future<void> _initializeFromCamera(Camera activeCamera) async {
    final currentModelMatrix = await activeCamera.getModelMatrix();
    final cameraPosition = currentModelMatrix.getTranslation();
    final directionToCamera = cameraPosition - targetPoint;

    _radius = directionToCamera.length;
    _radius = _radius.clamp(minZoomDistance, maxZoomDistance);

    if (_radius < 0.001) {
      _radius = minZoomDistance;
      _azimuth = 0.0;
      _elevation = math.pi / 4;
    } else {
      final dirToCameraNormalized = directionToCamera.normalized();
      // Elevation: angle with the XZ plane (plane perpendicular to worldUp)
      // Assuming worldUp is (0,1,0), elevation is asin(y)
      _elevation = math.asin(dirToCameraNormalized.dot(worldUp));

      // Azimuth: angle in the XZ plane.
      // Project dirToCameraNormalized onto the plane perpendicular to worldUp
      Vector3 projectionOnPlane = (dirToCameraNormalized - worldUp * math.sin(_elevation)).normalized();
      if (projectionOnPlane.length2 < 0.0001 && worldUp.dot(Vector3(0, 0, 1)).abs() < 0.99) {
        // looking straight up/down, pick a default reference for azimuth
        projectionOnPlane = Vector3(0, 0, 1); // if worldUp is Y, project onto XZ plane
      } else if (projectionOnPlane.length2 < 0.0001) {
        // if worldUp is Z, project onto XY plane
        projectionOnPlane = Vector3(1, 0, 0);
      }

      // Define a reference vector in the plane (e.g., world X-axis or Z-axis)
      // Let's use world Z-axis as the 0-azimuth reference, if not aligned with worldUp
      Vector3 referenceAzimuthVector = Vector3(0, 0, 1);
      if (worldUp.dot(referenceAzimuthVector).abs() > 0.99) {
        // If worldUp is Z, use X instead
        referenceAzimuthVector = Vector3(1, 0, 0);
      }
      // Ensure referenceAzimuthVector is also in the plane
      referenceAzimuthVector = (referenceAzimuthVector - worldUp * referenceAzimuthVector.dot(worldUp)).normalized();

      _azimuth = math.atan2(
        projectionOnPlane.cross(referenceAzimuthVector).dot(worldUp),
        projectionOnPlane.dot(referenceAzimuthVector),
      );
    }
    _elevation = _elevation.clamp(-math.pi / 2 + 0.01, math.pi / 2 - 0.01); // Clamp elevation
    _isInitialized = true;
  }

  /// Applies the accumulated pointer deltas to the camera in one update.
  /// With [app] set this runs once per rendered frame; otherwise it runs at
  /// the end of every event batch (legacy behavior).
  Future<void> _applyPending() async {
    if (_pendingDeltaAzimuth == 0 &&
        _pendingDeltaElevation == 0 &&
        _pendingDeltaRadius == 0 &&
        _radiusScaleFactor == 1.0) {
      return;
    }

    try {
      final camera = _camera ??= await view.getCamera();
      if (!_isInitialized) {
        await _initializeFromCamera(camera);
      }

      _azimuth += _pendingDeltaAzimuth;
      _elevation += _pendingDeltaElevation;
      _radius += _pendingDeltaRadius;
      _pendingDeltaAzimuth = 0;
      _pendingDeltaElevation = 0;
      _pendingDeltaRadius = 0;

      var radius = _radius * _radiusScaleFactor;

      // Clamp parameters
      _elevation = _elevation.clamp(-math.pi / 2 + 0.01, math.pi / 2 - 0.01); // Prevent gimbal lock at poles
      radius = radius.clamp(minZoomDistance, maxZoomDistance);
      _azimuth = _azimuth % (2 * math.pi); // Keep azimuth within 0-2PI range (optional)

      final double xOffset = radius * math.cos(_elevation) * math.sin(_azimuth);
      final double yOffset = radius * math.sin(_elevation);
      final double zOffset = radius * math.cos(_elevation) * math.cos(_azimuth);

      Vector3 cameraPosition;
      if (worldUp.dot(Vector3(0, 1, 0)).abs() > 0.99) {
        // Standard Y-up
        cameraPosition = targetPoint + Vector3(xOffset, yOffset, zOffset);
      } else if (worldUp.dot(Vector3(0, 0, 1)).abs() > 0.99) {
        cameraPosition =
            targetPoint +
            Vector3(
              radius * math.cos(_elevation) * math.cos(_azimuth), // x
              radius * math.cos(_elevation) * math.sin(_azimuth), // y
              radius * math.sin(_elevation), // z
            );
      } else {
        cameraPosition = targetPoint + Vector3(xOffset, yOffset, zOffset);
      }

      final modelMatrix = makeViewMatrix(cameraPosition, targetPoint, worldUp)..invert();

      await camera.setModelMatrix(modelMatrix);
    } catch (_) {
      // Camera may have been disposed.
      _camera = null;
    }
  }

  @override
  Future<void> handle(List<InputEvent> events) async {
    // Synchronous accumulation only; the combined update is applied once per
    // frame (or at the end of this batch when no app was provided).
    for (final event in events) {
      switch (event) {
        case ScrollEvent(delta: final scrollDelta):
          _pendingDeltaRadius += sensitivity.scrollWheelSensitivity * scrollDelta;
          break;

        case MouseEvent(
          type: final type,
          button: final button,
          localPosition: final localPosition,
          // delta: final mouseDelta // Using localPosition to calculate delta from _lastPointerPosition
        ):
          switch (type) {
            case MouseEventType.buttonDown:
              if (button == MouseButton.left) {
                // Typically left mouse button for orbit
                _isMouseDown = true;
                _lastPointerPosition = localPosition;
              }
              break;
            case MouseEventType.buttonUp:
              if (button == MouseButton.left) {
                _isMouseDown = false;
                _lastPointerPosition = null;
              }
              break;
            case MouseEventType.move:
            case MouseEventType.hover: // Some systems might only send hover when no buttons pressed
              if (event.type == MouseEventType.hover && !moveOnHover) {
                continue;
              }
              if (_isMouseDown && _lastPointerPosition != null) {
                final dragDelta = localPosition - _lastPointerPosition!;
                // X-drag affects azimuth, Y-drag affects elevation
                _pendingDeltaAzimuth -= dragDelta.x * sensitivity.mouseSensitivity; // Invert X for natural feel
                _pendingDeltaElevation -= dragDelta.y * sensitivity.mouseSensitivity; // Invert Y for natural feel
                _lastPointerPosition = localPosition;
              } else if (type == MouseEventType.hover) {
                // Allow hover to set initial if not dragging
                _lastPointerPosition = localPosition;
              }
              break;
          }
          break;
        case TouchEvent(type: final type, localPosition: _, delta: _):
          switch (type) {
            case TouchEventType.tap:
              break;
            default:
              break;
          }
          break;

        case ScaleUpdateEvent(
          numPointers: final numPointers,
          scale: final scaleFactor,
          localFocalPoint: _,
          localFocalPointDelta: final localFocalPointDelta,
        ):
          if (numPointers == 1) {
            _pendingDeltaAzimuth -= localFocalPointDelta!.$1 * sensitivity.touchSensitivity;
            _pendingDeltaElevation -= localFocalPointDelta.$2 * sensitivity.touchSensitivity;
          } else {
            _radiusScaleFactor = scaleFactor;
          }
        case ScaleEndEvent():
          _radius *= _radiusScaleFactor;
          _radiusScaleFactor = 1.0;
        default:
          break;
      }
    }

    if (app == null) {
      await _applyPending();
    }
  }

  @override
  Future dispose() async {
    final onFrame = _onFrame;
    if (onFrame != null) {
      await app?.unregisterRequestFrameHook(onFrame);
      _onFrame = null;
    }
    _camera = null;
  }
}
