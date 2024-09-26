// import 'package:thermion_dart/thermion_dart.dart';

// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';

// import 'package:vector_math/vector_math_64.dart';
// import 'dart:ui' show Offset;

// extension OffsetExtension on Offset {
//   Vector2 toVector2() {
//     return Vector2(dx, dy);
//   }
// }

// class ThermionGestureDetectorDesktop extends StatefulWidget {
//   final Widget? child;
//   final InputHandler gestureHandler;
//   final bool showControlOverlay;
//   final bool enableCamera;
//   final bool enablePicking;

//   const ThermionGestureDetectorDesktop({
//     Key? key,
//     required this.gestureHandler,
//     this.child,
//     this.showControlOverlay = false,
//     this.enableCamera = true,
//     this.enablePicking = true,
//   }) : super(key: key);

//   @override
//   State<StatefulWidget> createState() => _ThermionGestureDetectorDesktopState();
// }

// class _ThermionGestureDetectorDesktopState
//     extends State<ThermionGestureDetectorDesktop> {
  
//   @override
//   Widget build(BuildContext context) {
//     return Listener(
//       onPointerHover: (event) =>
//           widget.gestureHandler.onPointerHover(event.localPosition.toVector2(), event.delta.toVector2()),
//       onPointerSignal: (PointerSignalEvent pointerSignal) {
//         if (pointerSignal is PointerScrollEvent) {
//           widget.gestureHandler.onPointerScroll(
//               pointerSignal.localPosition.toVector2(), pointerSignal.scrollDelta.dy);
//         }
//       },
//       onPointerPanZoomStart: (pzs) {
//         throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
//       },
//       onPointerDown: (d) =>
//           widget.gestureHandler.onPointerDown(d.localPosition.toVector2(), d.buttons & kMiddleMouseButton != 0),
//       onPointerMove: (PointerMoveEvent d) =>
//           widget.gestureHandler.onPointerMove(d.localPosition.toVector2(), d.delta.toVector2(), d.buttons & kMiddleMouseButton != 0),
//       onPointerUp: (d) => widget.gestureHandler.onPointerUp(d.buttons),
//       child: widget.child,
//     );
//   }
// }
