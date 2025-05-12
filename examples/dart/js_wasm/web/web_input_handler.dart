import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:thermion_dart/thermion_dart.dart';

class WebInputHandler {
  final InputHandler inputHandler;
  final web.HTMLCanvasElement canvas;
  late double pixelRatio;

  final Map<int, Vector2> _touchPositions = {};

  WebInputHandler({
    required this.inputHandler,
    required this.canvas,
  }) {
    pixelRatio = web.window.devicePixelRatio;
    _initializeEventListeners();
  }

  void _initializeEventListeners() {
    canvas.addEventListener('mousedown', _onMouseDown.toJS);
    canvas.addEventListener('mousemove', _onMouseMove.toJS);
    canvas.addEventListener('mouseup', _onMouseUp.toJS);
    canvas.addEventListener('wheel', _onMouseWheel.toJS);
    web.window.addEventListener('keydown', _onKeyDown.toJS);
    web.window.addEventListener('keyup', _onKeyUp.toJS);

    canvas.addEventListener('touchstart', _onTouchStart.toJS);
    canvas.addEventListener('touchmove', _onTouchMove.toJS);
    canvas.addEventListener('touchend', _onTouchEnd.toJS);
    canvas.addEventListener('touchcancel', _onTouchCancel.toJS);
  }

  void _onMouseDown(web.MouseEvent event) {
    final localPos = _getLocalPositionFromEvent(event);
    final button = _getMouseButtonFromEvent(event);
    
    inputHandler.handle(MouseEvent(
      MouseEventType.buttonDown,
      button,
      localPos,
      Vector2.zero(),
    ));
    
    event.preventDefault();
  }

  void _onMouseMove(web.MouseEvent event) {
    final localPos = _getLocalPositionFromEvent(event);
    final delta = Vector2(event.movementX ?? 0, event.movementY ?? 0);
    final button = _getMouseButtonFromEvent(event);
    
    inputHandler.handle(MouseEvent(
      MouseEventType.move,
      button,
      localPos,
      delta,
    ));
    
    event.preventDefault();
  }

  void _onMouseUp(web.MouseEvent event) {
    final localPos = _getLocalPositionFromEvent(event);
    final button = _getMouseButtonFromEvent(event);
    
    inputHandler.handle(MouseEvent(
      MouseEventType.buttonUp,
      button,
      localPos,
      Vector2.zero(),
    ));
    
    event.preventDefault();
  }

  void _onMouseWheel(web.WheelEvent event) {
    final localPos = _getLocalPositionFromEvent(event);
    final delta = event.deltaY;
    
    inputHandler.handle(ScrollEvent(
      localPosition: localPos,
      delta: delta,
    ));
    
    event.preventDefault();
  }

  void _onKeyDown(web.KeyboardEvent event) {
    PhysicalKey? key = _getPhysicalKeyFromEvent(event);
    if (key != null) {
      inputHandler.handle(KeyEvent(KeyEventType.down, key));
    }
    event.preventDefault();
  }

  void _onKeyUp(web.KeyboardEvent event) {
    PhysicalKey? key = _getPhysicalKeyFromEvent(event);
    if (key != null) {
      inputHandler.handle(KeyEvent(KeyEventType.up, key));
    }
    event.preventDefault();
  }

  void _onTouchStart(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      final pos = _getLocalPositionFromTouch(touch);
      _touchPositions[touch.identifier] = pos;
    }

    final touchCount = event.touches.toList().length;
    if (touchCount == 1) {
      final touch = event.touches.toList().first;
      final pos = _getLocalPositionFromTouch(touch);
      inputHandler.handle(TouchEvent(
        TouchEventType.tap,
        pos,
        null,
      ));
    }

    if (touchCount >= 2) {
      final focalPoint = _calculateFocalPoint(event.touches.toList());
      inputHandler.handle(ScaleStartEvent(
        numPointers: touchCount,
        localFocalPoint: (focalPoint.x, focalPoint.y),
      ));
    }
    
    event.preventDefault();
  }

  void _onTouchMove(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      final id = touch.identifier;
      final currPos = _getLocalPositionFromTouch(touch);
      final prevPos = _touchPositions[id];

      if (prevPos != null) {
        _touchPositions[id] = currPos;
      }
    }

    final touchCount = event.touches.toList().length;
    if (touchCount >= 2) {
      final touches = event.touches.toList();
      final focalPoint = _calculateFocalPoint(touches);
      
      // Calculate scale
      final currPositions = touches.map((t) => _getLocalPositionFromTouch(t)).toList();
      final prevPositions = touches.map((t) => _touchPositions[t.identifier] ?? _getLocalPositionFromTouch(t)).toList();
      
      final currDist = (currPositions[0] - currPositions[1]).length;
      final prevDist = (prevPositions[0] - prevPositions[1]).length;
      final scale = prevDist > 0 ? currDist / prevDist : 1.0;
      
      // Calculate focal point delta
      final prevFocalPoint = _calculateFocalPoint(touches, prevPositions);
      final focalPointDelta = focalPoint - prevFocalPoint;
      
      inputHandler.handle(ScaleUpdateEvent(
        numPointers: touchCount,
        localFocalPoint: (focalPoint.x, focalPoint.y),
        localFocalPointDelta: (focalPointDelta.x, focalPointDelta.y),
        rotation: 0.0, // We don't track rotation in the web implementation
        scale: scale,
        horizontalScale: scale,
        verticalScale: scale,
      ));
    }
    
    event.preventDefault();
  }

  void _onTouchEnd(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      _touchPositions.remove(touch.identifier);
    }

    final touchCount = event.touches.toList().length;
    inputHandler.handle(ScaleEndEvent(
      numPointers: touchCount,
    ));
    
    event.preventDefault();
  }

  void _onTouchCancel(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      _touchPositions.remove(touch.identifier);
    }

    final touchCount = event.touches.toList().length;
    inputHandler.handle(ScaleEndEvent(
      numPointers: touchCount,
    ));
    
    event.preventDefault();
  }

  MouseButton? _getMouseButtonFromEvent(web.MouseEvent event) {
    if (event.button == 1 || (event.buttons & 4 != 0)) {
      return MouseButton.middle;
    } else if (event.button == 0 || (event.buttons & 1 != 0)) {
      return MouseButton.left;
    } else if (event.button == 2 || (event.buttons & 2 != 0)) {
      return MouseButton.right;
    }
    return null;
  }

  PhysicalKey? _getPhysicalKeyFromEvent(web.KeyboardEvent event) {
    switch (event.code) {
      case 'KeyW':
        return PhysicalKey.W;
      case 'KeyA':
        return PhysicalKey.A;
      case 'KeyS':
        return PhysicalKey.S;
      case 'KeyD':
        return PhysicalKey.D;
      default:
        return null;
    }
  }

  Vector2 _getLocalPositionFromEvent(web.Event event) {
    final rect = canvas.getBoundingClientRect();
    double clientX = 0, clientY = 0;

    if (event is web.MouseEvent) {
      clientX = event.clientX.toDouble();
      clientY = event.clientY.toDouble();
    } else if (event is web.TouchEvent) {
      final touch = event.touches.toList().firstOrNull;
      if (touch != null) {
        clientX = touch.clientX;
        clientY = touch.clientY;
      }
    }

    return Vector2(
      (clientX - rect.left) * pixelRatio,
      (clientY - rect.top) * pixelRatio,
    );
  }

  Vector2 _getLocalPositionFromTouch(web.Touch touch) {
    final rect = canvas.getBoundingClientRect();
    return Vector2(
      (touch.clientX - rect.left) * pixelRatio,
      (touch.clientY - rect.top) * pixelRatio,
    );
  }

  Vector2 _calculateFocalPoint(List<web.Touch> touches, [List<Vector2>? positions]) {
    if (touches.isEmpty) return Vector2.zero();
    
    final points = positions ?? touches.map((t) => _getLocalPositionFromTouch(t)).toList();
    
    Vector2 sum = Vector2.zero();
    for (var point in points) {
      sum += point;
    }
    
    return sum.scaled(1.0 / points.length);
  }

  void dispose() {
    canvas.removeEventListener('mousedown', _onMouseDown.toJS);
    canvas.removeEventListener('mousemove', _onMouseMove.toJS);
    canvas.removeEventListener('mouseup', _onMouseUp.toJS);
    canvas.removeEventListener('wheel', _onMouseWheel.toJS);
    web.window.removeEventListener('keydown', _onKeyDown.toJS);
    web.window.removeEventListener('keyup', _onKeyUp.toJS);
    canvas.removeEventListener('touchstart', _onTouchStart.toJS);
    canvas.removeEventListener('touchmove', _onTouchMove.toJS);
    canvas.removeEventListener('touchend', _onTouchEnd.toJS);
    canvas.removeEventListener('touchcancel', _onTouchCancel.toJS);
  }
}