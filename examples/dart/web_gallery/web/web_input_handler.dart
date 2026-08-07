import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Wires raw mouse/scroll (and basic touch) events to per-event callbacks.
///
/// The camera is updated on every pointer event -- not batched per frame.
/// Batching used to quantize motion: pointer events (~8ms) and frames (~16ms)
/// aren't phase-locked, so one frame would catch one event and the next two,
/// making the orbit advance in uneven steps. Applying per event keeps the
/// camera a continuous function of cumulative input, so each rendered frame
/// samples a smooth angle. Listeners do only cheap arithmetic + the callback;
/// no async work per event.
class WebInputHandler {
  final web.HTMLCanvasElement canvas;
  final void Function(double dx, double dy) onDrag;
  final void Function(double scroll) onScroll;

  WebInputHandler({
    required this.canvas,
    required this.onDrag,
    required this.onScroll,
  }) {
    canvas.addEventListener('mousedown', _onMouseDown.toJS);
    canvas.addEventListener('mousemove', _onMouseMove.toJS);
    web.window.addEventListener('mouseup', _onMouseUp.toJS);
    canvas.addEventListener('wheel', _onMouseWheel.toJS);

    canvas.addEventListener('touchstart', _onTouchStart.toJS);
    canvas.addEventListener('touchmove', _onTouchMove.toJS);
    canvas.addEventListener('touchend', _onTouchEnd.toJS);
  }

  bool _leftDown = false;
  // Reference position for computing deltas via clientX/Y (more reliable than
  // movementX, which has quirks on hi-DPI / coalesced events).
  double _lastX = 0;
  double _lastY = 0;

  // Touch tracking.
  double _lastTouchX = 0;
  double _lastTouchY = 0;
  double _lastPinch = 0;

  void _onMouseDown(web.MouseEvent e) {
    if (e.button == 0) {
      _leftDown = true;
      _lastX = e.clientX.toDouble();
      _lastY = e.clientY.toDouble();
    }
    e.preventDefault();
  }

  void _onMouseMove(web.MouseEvent e) {
    if (e.buttons == 0) {
      _leftDown = false;
      return;
    }
    if (!_leftDown) return;
    final x = e.clientX.toDouble();
    final y = e.clientY.toDouble();
    onDrag(x - _lastX, y - _lastY);
    _lastX = x;
    _lastY = y;
    e.preventDefault();
  }

  void _onMouseUp(web.MouseEvent e) {
    if (e.button == 0) _leftDown = false;
  }

  void _onMouseWheel(web.WheelEvent e) {
    onScroll(e.deltaY.toDouble());
    e.preventDefault();
  }

  void _onTouchStart(web.TouchEvent e) {
    final ts = e.touches.toList();
    if (ts.length == 1) {
      _lastTouchX = ts[0].clientX;
      _lastTouchY = ts[0].clientY;
    } else if (ts.length == 2) {
      _lastPinch = _dist(ts[0], ts[1]);
    }
    e.preventDefault();
  }

  void _onTouchMove(web.TouchEvent e) {
    final ts = e.touches.toList();
    if (ts.length == 1) {
      final t = ts[0];
      onDrag(t.clientX - _lastTouchX, t.clientY - _lastTouchY);
      _lastTouchX = t.clientX;
      _lastTouchY = t.clientY;
    } else if (ts.length >= 2) {
      final d = _dist(ts[0], ts[1]);
      if (_lastPinch > 0) onScroll((_lastPinch - d) * 1.5);
      _lastPinch = d;
    }
    e.preventDefault();
  }

  void _onTouchEnd(web.TouchEvent e) {
    _lastPinch = 0;
    e.preventDefault();
  }

  double _dist(web.Touch a, web.Touch b) {
    final dx = a.clientX - b.clientX;
    final dy = a.clientY - b.clientY;
    return math.sqrt(dx * dx + dy * dy);
  }

  void dispose() {
    canvas.removeEventListener('mousedown', _onMouseDown.toJS);
    canvas.removeEventListener('mousemove', _onMouseMove.toJS);
    web.window.removeEventListener('mouseup', _onMouseUp.toJS);
    canvas.removeEventListener('wheel', _onMouseWheel.toJS);
    canvas.removeEventListener('touchstart', _onTouchStart.toJS);
    canvas.removeEventListener('touchmove', _onTouchMove.toJS);
    canvas.removeEventListener('touchend', _onTouchEnd.toJS);
  }
}
