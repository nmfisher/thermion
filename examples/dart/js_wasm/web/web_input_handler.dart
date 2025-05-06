import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:thermion_dart/thermion_dart.dart';

class WebInputHandler {
  final DelegateInputHandler inputHandler;
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
    print("MOUSEDOWN");
    final localPos = _getLocalPositionFromEvent(event);
    final isMiddle = event.button == 1;
    inputHandler.onPointerDown(localPos, isMiddle);
    event.preventDefault();
  }

  void _onMouseMove(web.MouseEvent event) {
    final localPos = _getLocalPositionFromEvent(event);
    
    final delta = Vector2(event.movementX ?? 0, event.movementY ?? 0);
    final isMiddle = event.buttons & 4 != 0;
    inputHandler.onPointerMove(localPos, delta, isMiddle);
    event.preventDefault();
  }

  void _onMouseUp(web.MouseEvent event) {
    final isMiddle = event.button == 1;
    inputHandler.onPointerUp(isMiddle);
    event.preventDefault();
  }

  void _onMouseWheel(web.WheelEvent event) {
    final localPos = _getLocalPositionFromEvent(event);
    final delta = event.deltaY;
    inputHandler.onPointerScroll(localPos, delta);
    event.preventDefault();
  }

  void _onKeyDown(web.KeyboardEvent event) {
    PhysicalKey? key;
    switch (event.code) {
      case 'KeyW':
        key = PhysicalKey.W;
        break;
      case 'KeyA':
        key = PhysicalKey.A;
        break;
      case 'KeyS':
        key = PhysicalKey.S;
        break;
      case 'KeyD':
        key = PhysicalKey.D;
        break;
    }
    if (key != null) inputHandler.keyDown(key);
    event.preventDefault();
  }

  void _onKeyUp(web.KeyboardEvent event) {
    PhysicalKey? key;
    switch (event.code) {
      case 'KeyW':
        key = PhysicalKey.W;
        break;
      case 'KeyA':
        key = PhysicalKey.A;
        break;
      case 'KeyS':
        key = PhysicalKey.S;
        break;
      case 'KeyD':
        key = PhysicalKey.D;
        break;
    }
    if (key != null) inputHandler.keyUp(key);
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
      inputHandler.onPointerDown(pos, false);
    }

    _handleScaleStart(touchCount, null);
    event.preventDefault();
  }

  void _onTouchMove(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      final id = touch.identifier;
      final currPos = _getLocalPositionFromTouch(touch);
      final prevPos = _touchPositions[id];

      if (prevPos != null) {
        final delta = currPos - prevPos;
        inputHandler.onPointerMove(currPos, delta, false);
      }

      _touchPositions[id] = currPos;
    }

    final touchCount = event.touches.toList().length;
    if (touchCount >= 2) {
      final touches = event.touches.toList().toList();
      final touch0 = touches[0];
      final touch1 = touches[1];
      final pos0 = _getLocalPositionFromTouch(touch0);
      final pos1 = _getLocalPositionFromTouch(touch1);
      final prevPos0 = _touchPositions[touch0.identifier];
      final prevPos1 = _touchPositions[touch1.identifier];

      if (prevPos0 != null && prevPos1 != null) {
        final prevDist = (prevPos0 - prevPos1).length;
        final currDist = (pos0 - pos1).length;
        final scale = currDist / prevDist;
        final focalPoint = (pos0 + pos1) * 0.5;

        inputHandler.onScaleUpdate(
          focalPoint,
          Vector2(0, 0),
          0.0,
          0.0,
          scale,
          touchCount,
          0.0,
          null,
        );
      }
    }

    event.preventDefault();
  }

  void _onTouchEnd(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      _touchPositions.remove(touch.identifier);
    }

    final touchCount = event.touches.toList().length;
    inputHandler.onScaleEnd(touchCount, 0.0);
    event.preventDefault();
  }

  void _onTouchCancel(web.TouchEvent event) {
    for (var touch in event.changedTouches.toList()) {
      _touchPositions.remove(touch.identifier);
    }

    final touchCount = event.touches.toList().length;
    inputHandler.onScaleEnd(touchCount, 0.0);
    event.preventDefault();
  }

  void _handleScaleStart(int pointerCount, Duration? sourceTimestamp) {
    inputHandler.onScaleStart(Vector2.zero(), pointerCount, sourceTimestamp);
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
