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

  /// Multiplicative pinch-zoom accumulated since the last applied update.
  /// ScaleUpdateEvent reports the gesture's *cumulative* scale, so each
  /// update contributes the ratio to the last-seen scale of the gesture and
  /// successive updates multiply correctly across per-frame applies.
  double _pendingRadiusScale = 1.0;

  /// Cumulative scale last seen in the current pinch gesture; 1.0 between
  /// gestures.
  double _lastPinchScale = 1.0;

  /// True once [handle] accumulated anything that [_applyPending] has not
  /// applied yet. Without this flag a ScaleEndEvent arriving in the same
  /// batch as the final ScaleUpdateEvent would leave every pending delta
  /// zero and the update would never reach the camera; it also stops
  /// per-frame camera rewrites while a two-finger hold is stationary.
  bool _hasPendingUpdate = false;

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
    if (!_hasPendingUpdate) {
      return;
    }

    if (_pendingDeltaAzimuth == 0 &&
        _pendingDeltaElevation == 0 &&
        _pendingDeltaRadius == 0 &&
        _pendingRadiusScale == 1.0) {
      // A batch that accumulated nothing (e.g. a tap-only batch): leave the
      // camera untouched and just release the pending flag.
      _hasPendingUpdate = false;
      return;
    }

    try {
      final camera = _camera ??= await view.getCamera();
      // Initialize from the camera first so a pinch accumulated before the
      // first update scales the camera's real radius, not the placeholder
      // default.
      if (!_isInitialized) {
        await _initializeFromCamera(camera);
      }

      _azimuth += _pendingDeltaAzimuth;
      _elevation += _pendingDeltaElevation;
      // Clamp the stored radius itself, not just a local copy: an unclamped
      // _radius could wind up to 0 (or negative) via scroll windup or a
      // degenerate pinch, after which every multiplicative pinch applies to a
      // zero/negative base and zoom is bricked or inverted. The floor keeps
      // the base non-zero even when minZoomDistance <= 0.
      _radius = ((_radius + _pendingDeltaRadius) * _pendingRadiusScale)
          .clamp(math.max(minZoomDistance, 1e-4), maxZoomDistance);
      _pendingDeltaAzimuth = 0;
      _pendingDeltaElevation = 0;
      _pendingDeltaRadius = 0;
      _pendingRadiusScale = 1.0;
      _hasPendingUpdate = false;

      final radius = _radius;

      // Clamp parameters
      _elevation = _elevation.clamp(-math.pi / 2 + 0.01, math.pi / 2 - 0.01); // Prevent gimbal lock at poles
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
    _hasPendingUpdate = true;
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

        case ScaleStartEvent():
          // A new gesture's scale is cumulative from 1.0 again.
          _lastPinchScale = 1.0;
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
            // Multiplicative accumulation: fold in the ratio to the last
            // scale seen in this gesture. Never fold into [_radius] here —
            // [_radius] may still be the uninitialized placeholder until
            // [_initializeFromCamera] has run inside [_applyPending].
            if (scaleFactor > 0 && _lastPinchScale > 0) {
              _pendingRadiusScale *= scaleFactor / _lastPinchScale;
              _lastPinchScale = scaleFactor;
            }
            // Degenerate samples (both pointers at the same pixel report a
            // cumulative span of 0) are ignored above rather than folded in:
            // a zero ratio would collapse _pendingRadiusScale to 0 and zero
            // out the radius in [_applyPending].
          }
        case ScaleEndEvent():
          // The gesture's increments were already accumulated per update;
          // anything still pending is applied by the next [_applyPending]
          // (flagged above), so the final pinch increment can no longer be
          // dropped by a zero-delta early return.
          _lastPinchScale = 1.0;
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
