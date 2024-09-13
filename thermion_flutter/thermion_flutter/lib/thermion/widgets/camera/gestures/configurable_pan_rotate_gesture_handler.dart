import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';

class ConfigurablePanRotateGestureHandler implements ThermionGestureHandler {
  
  final ThermionViewer viewer;
  final Logger _logger = Logger("ConfigurablePanRotateGestureHandler");

  ConfigurablePanRotateGestureHandler({
    required this.viewer,
  });

  @override
  Future<void> onPointerHover(Offset localPosition) async {
   // noop
  }

  // @override
  // Future<void> onPointerScroll(Offset localPosition, double scrollDelta) async {
  //   await _zoom(localPosition, scrollDelta);
  // }

  // @override
  // Future<void> onPointerDown(Offset localPosition, int buttons) async {
  //   if (buttons == kMiddleMouseButton) {
  //     await viewer.rotateStart(localPosition.dx, localPosition.dy);
  //   } else if (buttons == kPrimaryMouseButton) {
  //     await viewer.panStart(localPosition.dx, localPosition.dy);
  //   }
  // }

  // @override
  // Future<void> onPointerMove(
  //     Offset localPosition, Offset delta, int buttons) async {
  //   switch (_currentState) {
  //     case ThermionGestureState.NULL:
  //       break;
  //     case ThermionGestureState.ENTITY_HIGHLIGHTED:
  //       await _handleEntityHighlightedMove(localPosition);
  //       break;
  //     case ThermionGestureState.GIZMO_ATTACHED:
  //       break;
  //     case ThermionGestureState.ROTATING:
  //       if (enableCamera) {
  //         await viewer.rotateUpdate(localPosition.dx, localPosition.dy);
  //       }
  //       break;
  //     case ThermionGestureState.PANNING:
  //       if (enableCamera) {
  //         await viewer.panUpdate(localPosition.dx, localPosition.dy);
  //       }
  //       break;
  //   }
  // }

  // @override
  // Future<void> onPointerUp(int buttons) async {
  //   switch (_currentState) {
  //     case ThermionGestureState.ROTATING:
  //       await viewer.rotateEnd();
  //       _currentState = ThermionGestureState.NULL;
  //       break;
  //     case ThermionGestureState.PANNING:
  //       await viewer.panEnd();
  //       _currentState = ThermionGestureState.NULL;
  //       break;
  //     default:
  //       break;
  //   }
  // }

  // Future<void> _handleEntityHighlightedMove(Offset localPosition) async {
  //   if (_highlightedEntity != null) {
  //     await viewer.queuePositionUpdateFromViewportCoords(
  //       _highlightedEntity!,
  //       localPosition.dx,
  //       localPosition.dy,
  //     );
  //   }
  // }

  // Future<void> _zoom(Offset localPosition, double scrollDelta) async {
  //   _scrollTimer?.cancel();
  //   await viewer.zoomBegin();
  //   await viewer.zoomUpdate(
  //       localPosition.dx, localPosition.dy, scrollDelta > 0 ? 1 : -1);

  //   _scrollTimer = Timer(const Duration(milliseconds: 100), () async {
  //     await viewer.zoomEnd();
  //   });
  // }

  @override
  void dispose() {
  }

  @override
  Future<bool> get initialized => viewer.initialized;
  
  @override
  GestureAction getActionForType(GestureType type) {
    // TODO: implement getActionForType
    throw UnimplementedError();
  }
  
  @override
  Future<void> onScaleEnd() {
    // TODO: implement onScaleEnd
    throw UnimplementedError();
  }
  
  @override
  Future<void> onScaleStart() {
    // TODO: implement onScaleStart
    throw UnimplementedError();
  }
  
  @override
  Future<void> onScaleUpdate() {
    // TODO: implement onScaleUpdate
    throw UnimplementedError();
  }
  
  @override
  void setActionForType(GestureType type, GestureAction action) {
    // TODO: implement setActionForType
  }
  
  @override
  Future<void> onPointerDown(Offset localPosition, int buttons) {
    // TODO: implement onPointerDown
    throw UnimplementedError();
  }
  
  @override
  Future<void> onPointerMove(Offset localPosition, Offset delta, int buttons) {
    // TODO: implement onPointerMove
    throw UnimplementedError();
  }
  
  @override
  Future<void> onPointerScroll(Offset localPosition, double scrollDelta) {
    // TODO: implement onPointerScroll
    throw UnimplementedError();
  }
  
  @override
  Future<void> onPointerUp(int buttons) {
    // TODO: implement onPointerUp
    throw UnimplementedError();
  }
}
