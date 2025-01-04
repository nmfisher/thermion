// import 'dart:async';

// import 'package:thermion_dart/thermion_dart.dart';
// import 'package:vector_math/vector_math_64.dart';

// import '../input_handler.dart';

// class GizmoPickingHandler implements InputHandler {
//   final ThermionViewer viewer;
//   late final GizmoAsset _translationGizmo;

//   GizmoPickingHandler(this.viewer) {}

//   final _initialized = Completer<bool>();

//   Future initialize() async {
//     if (_initialized.isCompleted) {
//       throw Exception("Already initialized");
//     }
//     final view = await viewer.getViewAt(0);
//     _translationGizmo = await viewer.createGizmo(view, GizmoType.translation);
//     _initialized.complete(true);
//   }

//   Future dispose() async {
//     await viewer.destroyAsset(_translationGizmo);
//   }

//   @override
//   Stream get cameraUpdated => throw UnimplementedError();

//   @override
//   InputAction? getActionForType(InputType gestureType) {
//     throw UnimplementedError();
//   }

//   @override
//   Future<bool> get initialized => _initialized.future;

//   @override
//   void keyDown(PhysicalKey key) {}

//   @override
//   void keyUp(PhysicalKey key) {}

//   @override
//   Future<void> onPointerDown(Vector2 localPosition, bool isMiddle) {
//     viewer.pick(localPosition.x.floor(), localPosition.y.floor(), (axis) {

//     })
//     // _translationGizmo.pick(
//     //     localPosition.x.floor(), localPosition.y.floor(), (axis) {});
//   }

//   @override
//   Future<void> onPointerHover(Vector2 localPosition, Vector2 delta) {
//     // TODO: implement onPointerHover
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> onPointerMove(
//       Vector2 localPosition, Vector2 delta, bool isMiddle) {
//     // TODO: implement onPointerMove
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> onPointerScroll(Vector2 localPosition, double scrollDelta) {
//     // TODO: implement onPointerScroll
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> onPointerUp(bool isMiddle) {
//     // TODO: implement onPointerUp
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> onScaleEnd(int pointerCount, double velocity) {
//     // TODO: implement onScaleEnd
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> onScaleStart(
//       Vector2 focalPoint, int pointerCount, Duration? sourceTimestamp) {
//     // TODO: implement onScaleStart
//     throw UnimplementedError();
//   }

//   @override
//   Future<void> onScaleUpdate(
//       Vector2 focalPoint,
//       Vector2 focalPointDelta,
//       double horizontalScale,
//       double verticalScale,
//       double scale,
//       int pointerCount,
//       double rotation,
//       Duration? sourceTimestamp) {
//     // TODO: implement onScaleUpdate
//     throw UnimplementedError();
//   }

//   @override
//   void setActionForType(InputType gestureType, InputAction gestureAction) {
//     // TODO: implement setActionForType
//   }
// }
// //   final ThermionViewer viewer;
// //   final bool enableCamera;
// //   final bool enablePicking;
// //   final Logger _logger = Logger("PickingCameraGestureHandler");

// //   AbstractGizmo? _gizmo;
// //   Timer? _scrollTimer;
// //   ThermionEntity? _highlightedEntity;
// //   StreamSubscription<FilamentPickResult>? _pickResultSubscription;

// //   bool _gizmoAttached = false;

// //   PickingCameraGestureHandler({
// //     required this.viewer,
// //     this.enableCamera = true,
// //     this.enablePicking = true,
// //   }) {
// //     try {
// //       _gizmo = viewer.gizmo;
// //     } catch (err) {
// //       _logger.warning(
// //           "Failed to get gizmo. If you are running on WASM, this is expected");
// //     }

// //     _pickResultSubscription = viewer.pickResult.listen(_onPickResult);

// //     // Add keyboard listener
// //     RawKeyboard.instance.addListener(_handleKeyEvent);
// //   }

// //   @override
// //   ThermionGestureState get currentState => _currentState;

// //   void _handleKeyEvent(RawKeyEvent event) {
// //     if (event is RawKeyDownEvent &&
// //         event.logicalKey == LogicalKeyboardKey.escape) {
// //       _resetToNullState();
// //     }
// //   }

// //   void _resetToNullState() async {
// //     _currentState = ThermionGestureState.NULL;
// //     if (_highlightedEntity != null) {
// //       await viewer.removeStencilHighlight(_highlightedEntity!);
// //       _highlightedEntity = null;
// //     }
// //   }

// //   void _onPickResult(FilamentPickResult result) async {
// //     var targetEntity = await viewer.getAncestor(result.entity) ?? result.entity;

// //     if (_highlightedEntity != targetEntity) {
// //       if (_highlightedEntity != null) {
// //         await viewer.removeStencilHighlight(_highlightedEntity!);
// //       }

// //       _highlightedEntity = targetEntity;
// //       if (_highlightedEntity != null) {
// //         await viewer.setStencilHighlight(_highlightedEntity!);
// //         _gizmo?.attach(_highlightedEntity!);
// //       }
// //     }
// //   }

// //   @override
// //   Future<void> onPointerHover(Offset localPosition, Offset delta) async {
// //     if (_gizmoAttached) {
// //       _gizmo?.checkHover(localPosition.dx, localPosition.dy);
// //     }

// //     if (_highlightedEntity != null) {
// //       await viewer.queuePositionUpdateFromViewportCoords(
// //         _highlightedEntity!,
// //         localPosition.dx,
// //         localPosition.dy,
// //       );
// //     }
// //   }

// //   @override
// //   Future<void> onPointerScroll(Offset localPosition, double scrollDelta) async {
// //     if (!enableCamera) {
// //       return;
// //     }
// //     if (_currentState == ThermionGestureState.NULL ||
// //         _currentState == ThermionGestureState.ZOOMING) {
// //       await _zoom(localPosition, scrollDelta);
// //     }
// //   }

// //   @override
// //   Future<void> onPointerDown(Offset localPosition, int buttons) async {
// //     if (_highlightedEntity != null) {
// //       _resetToNullState();
// //       return;
// //     }

// //     if (enablePicking && buttons != kMiddleMouseButton) {
// //       viewer.pick(localPosition.dx.toInt(), localPosition.dy.toInt());
// //     }

// //     if (buttons == kMiddleMouseButton && enableCamera) {
// //       await viewer.rotateStart(localPosition.dx, localPosition.dy);
// //       _currentState = ThermionGestureState.ROTATING;
// //     } else if (buttons == kPrimaryMouseButton && enableCamera) {
// //       await viewer.panStart(localPosition.dx, localPosition.dy);
// //       _currentState = ThermionGestureState.PANNING;
// //     }
// //   }

// //   @override
// //   Future<void> onPointerMove(
// //       Offset localPosition, Offset delta, int buttons) async {
// //     if (_highlightedEntity != null) {
// //       await _handleEntityHighlightedMove(localPosition);
// //       return;
// //     }

// //     switch (_currentState) {
// //       case ThermionGestureState.NULL:
// //         break;

// //       case ThermionGestureState.ROTATING:
// //         if (enableCamera) {
// //           await viewer.rotateUpdate(localPosition.dx, localPosition.dy);
// //         }
// //         break;
// //       case ThermionGestureState.PANNING:
// //         if (enableCamera) {
// //           await viewer.panUpdate(localPosition.dx, localPosition.dy);
// //         }
// //         break;
// //       case ThermionGestureState.ZOOMING:
// //         // ignore
// //         break;
// //     }
// //   }

// //   @override
// //   Future<void> onPointerUp(int buttons) async {
// //     switch (_currentState) {
// //       case ThermionGestureState.ROTATING:
// //         await viewer.rotateEnd();
// //         _currentState = ThermionGestureState.NULL;
// //         break;
// //       case ThermionGestureState.PANNING:
// //         await viewer.panEnd();
// //         _currentState = ThermionGestureState.NULL;
// //         break;
// //       default:
// //         break;
// //     }
// //   }

// //   Future<void> _handleEntityHighlightedMove(Offset localPosition) async {
// //     if (_highlightedEntity != null) {
// //       await viewer.queuePositionUpdateFromViewportCoords(
// //         _highlightedEntity!,
// //         localPosition.dx,
// //         localPosition.dy,
// //       );
// //     }
// //   }

// //   Future<void> _zoom(Offset localPosition, double scrollDelta) async {
// //     _scrollTimer?.cancel();
// //     _currentState = ThermionGestureState.ZOOMING;
// //     await viewer.zoomBegin();
// //     await viewer.zoomUpdate(
// //         localPosition.dx, localPosition.dy, scrollDelta > 0 ? 1 : -1);

// //     _scrollTimer = Timer(const Duration(milliseconds: 100), () async {
// //       await viewer.zoomEnd();
// //       _currentState = ThermionGestureState.NULL;
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     _pickResultSubscription?.cancel();
// //     if (_highlightedEntity != null) {
// //       viewer.removeStencilHighlight(_highlightedEntity!);
// //     }
// //     RawKeyboard.instance.removeListener(_handleKeyEvent);
// //   }

// //   @override
// //   Future<bool> get initialized => viewer.initialized;

// //   @override
// //   InputAction getActionForType(InputType type) {
// //     // TODO: implement getActionForType
// //     throw UnimplementedError();
// //   }

// //   @override
// //   Future<void> onScaleEnd() {
// //     // TODO: implement onScaleEnd
// //     throw UnimplementedError();
// //   }

// //   @override
// //   Future<void> onScaleStart() {
// //     // TODO: implement onScaleStart
// //     throw UnimplementedError();
// //   }

// //   @override
// //   Future<void> onScaleUpdate() {
// //     // TODO: implement onScaleUpdate
// //     throw UnimplementedError();
// //   }

// //   @override
// //   void setActionForType(InputType type, InputAction action) {
// //     // TODO: implement setActionForType
// //   }
// // }
