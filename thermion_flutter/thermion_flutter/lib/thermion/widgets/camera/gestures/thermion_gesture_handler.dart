import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

enum GestureType { POINTER_HOVER, POINTER_DOWN, SCALE }

enum GestureAction {
  PAN_CAMERA,
  ROTATE_CAMERA,
  ZOOM_CAMERA,
  TRANSLATE_ENTITY,
  ROTATE_ENTITY
}

enum ThermionGestureState {
  NULL,
  ROTATING,
  PANNING,
  ZOOMING, // aka SCROLL
}

abstract class ThermionGestureHandler {
  GestureAction getActionForType(GestureType type);
  void setActionForType(GestureType type, GestureAction action);
  Future<void> onPointerHover(Offset localPosition);
  Future<void> onPointerScroll(Offset localPosition, double scrollDelta);
  Future<void> onPointerDown(Offset localPosition, int buttons);
  Future<void> onPointerMove(Offset localPosition, Offset delta, int buttons);
  Future<void> onPointerUp(int buttons);
  Future<void> onScaleStart();
  Future<void> onScaleUpdate();
  Future<void> onScaleEnd();
  Future<bool> get initialized;
  void dispose();
}

// enum ThermionGestureState {
//   NULL,
//   ENTITY_HIGHLIGHTED,
//   GIZMO_ATTACHED,
//   ROTATING,
//   PANNING,
// }

// class ThermionGestureHandler {
//   final ThermionViewer viewer;
//   final bool enableCamera;
//   final bool enablePicking;
//   final Logger _logger = Logger("ThermionGestureHandler");

//   ThermionGestureState _currentState = ThermionGestureState.NULL;
//   AbstractGizmo? _gizmo;
//   Timer? _scrollTimer;
//   ThermionEntity? _highlightedEntity;
//   StreamSubscription<FilamentPickResult>? _pickResultSubscription;

//   ThermionGestureHandler({
//     required this.viewer,
//     this.enableCamera = true,
//     this.enablePicking = true,
//   }) {
//     try {
//       _gizmo = viewer.gizmo;
//     } catch (err) {
//       _logger.warning(
//           "Failed to get gizmo. If you are running on WASM, this is expected");
//     }

//     _pickResultSubscription = viewer.pickResult.listen(_onPickResult);

//     // Add keyboard listener
//     RawKeyboard.instance.addListener(_handleKeyEvent);
//   }

//   void _handleKeyEvent(RawKeyEvent event) {
//     if (event is RawKeyDownEvent &&
//         event.logicalKey == LogicalKeyboardKey.escape) {
//       _resetToNullState();
//     }
//   }

//   void _resetToNullState() async {
//     // set current state to NULL first, so that any subsequent pointer movements
//     // won't attempt to translate a deleted entity
//     _currentState = ThermionGestureState.NULL;
//     if (_highlightedEntity != null) {
//       await viewer.removeStencilHighlight(_highlightedEntity!);
//       _highlightedEntity = null;
//     }
//   }

//   void _onPickResult(FilamentPickResult result) async {
//     var targetEntity = await viewer.getAncestor(result.entity) ?? result.entity;

//     if (_highlightedEntity != targetEntity) {
//       if (_highlightedEntity != null) {
//         await viewer.removeStencilHighlight(_highlightedEntity!);
//       }

//       _highlightedEntity = targetEntity;
//       if (_highlightedEntity != null) {
//         await viewer.setStencilHighlight(_highlightedEntity!);
//       }

//       _currentState = _highlightedEntity != null
//           ? ThermionGestureState.ENTITY_HIGHLIGHTED
//           : ThermionGestureState.NULL;
//     }
//   }

//   Future<void> onPointerHover(Offset localPosition) async {
//     if (_currentState == ThermionGestureState.GIZMO_ATTACHED) {
//       _gizmo?.checkHover(localPosition.dx, localPosition.dy);
//     }

//     // Update highlighted entity position
//     if (_highlightedEntity != null) {
//       await viewer.queuePositionUpdateFromViewportCoords(
//         _highlightedEntity!,
//         localPosition.dx,
//         localPosition.dy,
//       );
//     }
//   }

//   Future<void> onPointerScroll(Offset localPosition, double scrollDelta) async {
//     if (_currentState == ThermionGestureState.NULL && enableCamera) {
//       await _zoom(localPosition, scrollDelta);
//     }
//   }

//   Future<void> onPointerDown(Offset localPosition, int buttons) async {
//     if (_currentState == ThermionGestureState.ENTITY_HIGHLIGHTED) {
//       _resetToNullState();
//       return;
//     }

//     if (enablePicking && buttons != kMiddleMouseButton) {
//       viewer.pick(localPosition.dx.toInt(), localPosition.dy.toInt());
//     }

//     if (buttons == kMiddleMouseButton && enableCamera) {
//       await viewer.rotateStart(localPosition.dx, localPosition.dy);
//       _currentState = ThermionGestureState.ROTATING;
//     } else if (buttons == kPrimaryMouseButton && enableCamera) {
//       await viewer.panStart(localPosition.dx, localPosition.dy);
//       _currentState = ThermionGestureState.PANNING;
//     }
//   }

//   Future<void> onPointerMove(
//       Offset localPosition, Offset delta, int buttons) async {
//     switch (_currentState) {
//       case ThermionGestureState.NULL:
//         // This case should not occur now, as we set the state on pointer down
//         break;
//       case ThermionGestureState.ENTITY_HIGHLIGHTED:
//         await _handleEntityHighlightedMove(localPosition);
//         break;
//       case ThermionGestureState.GIZMO_ATTACHED:
//         // Do nothing
//         break;
//       case ThermionGestureState.ROTATING:
//         if (enableCamera) {
//           await viewer.rotateUpdate(localPosition.dx, localPosition.dy);
//         }
//         break;
//       case ThermionGestureState.PANNING:
//         if (enableCamera) {
//           await viewer.panUpdate(localPosition.dx, localPosition.dy);
//         }
//         break;
//     }
//   }

//   Future<void> onPointerUp(int buttons) async {
//     switch (_currentState) {
//       case ThermionGestureState.ROTATING:
//         await viewer.rotateEnd();
//         _currentState = ThermionGestureState.NULL;
//         break;
//       case ThermionGestureState.PANNING:
//         await viewer.panEnd();
//         _currentState = ThermionGestureState.NULL;
//         break;
//       default:
//         // For other states, no action needed
//         break;
//     }
//   }

//   Future<void> _handleEntityHighlightedMove(Offset localPosition) async {
//     if (_highlightedEntity != null) {
//       await viewer.queuePositionUpdateFromViewportCoords(
//         _highlightedEntity!,
//         localPosition.dx,
//         localPosition.dy,
//       );
//     }
//   }

//   Future<void> _zoom(Offset localPosition, double scrollDelta) async {
//     _scrollTimer?.cancel();
//     await viewer.zoomBegin();
//     await viewer.zoomUpdate(
//         localPosition.dx, localPosition.dy, scrollDelta > 0 ? 1 : -1);

//     _scrollTimer = Timer(const Duration(milliseconds: 100), () async {
//       await viewer.zoomEnd();
//     });
//   }

//   void dispose() {
//     _pickResultSubscription?.cancel();
//     if (_highlightedEntity != null) {
//       viewer.removeStencilHighlight(_highlightedEntity!);
//     }
//     // Remove keyboard listener
//     RawKeyboard.instance.removeListener(_handleKeyEvent);
//   }
// }
