import 'dart:async';
import 'package:thermion_dart/src/viewer/viewer.dart';



// abstract class BaseGizmo extends Gizmo {
//   final ThermionEntity x;
//   final ThermionEntity y;
//   final ThermionEntity z;
//   final ThermionEntity center;

//   ThermionEntity? _activeAxis;
//   ThermionEntity? _activeEntity;
//   ThermionViewer viewer;

//   bool _visible = false;
//   bool get isVisible => _visible;

//   bool _isHovered = false;
//   bool get isHovered => _isHovered;

//   final Set<ThermionEntity> ignore;

//   Stream<Aabb2> get boundingBox => _boundingBoxController.stream;
//   final _boundingBoxController = StreamController<Aabb2>.broadcast();

//   ThermionEntity get entity => center;

//   BaseGizmo(
//       {required this.x,
//       required this.y,
//       required this.z,
//       required this.center,
//       required this.viewer,
//       this.ignore = const <ThermionEntity>{}}) {
//     onPick(_onGizmoPickResult);
//   }

//   final _stopwatch = Stopwatch();

//   double _transX = 0.0;
//   double _transY = 0.0;

//   Future translate(double transX, double transY) async {
//     if (!_stopwatch.isRunning) {
//       _stopwatch.start();
//     }

//     _transX += transX;
//     _transY += transY;

//     if (_stopwatch.elapsedMilliseconds < 16) {
//       return;
//     }

//     final axis = Vector3(_activeAxis == x ? 1.0 : 0.0,
//         _activeAxis == y ? 1.0 : 0.0, _activeAxis == z ? 1.0 : 0.0);

//     await viewer.queueRelativePositionUpdateWorldAxis(
//         _activeEntity!,
//         _transX,
//         -_transY, // flip the sign because "up" in NDC Y axis is positive, but negative in Flutter
//         axis.x,
//         axis.y,
//         axis.z);
//     _transX = 0;
//     _transY = 0;
//     _stopwatch.reset();
//   }

//   void reset() {
//     _activeAxis = null;
//   }

//   void _onGizmoPickResult(FilamentPickResult result) async {
//     if (result.entity == x || result.entity == y || result.entity == z) {
//       _activeAxis = result.entity;
//       _isHovered = true;
//     } else if (result.entity == 0) {
//       _activeAxis = null;
//       _isHovered = false;
//     } else {
//       throw Exception("Unexpected gizmo pick result");
//     }
//   }

//   Future attach(ThermionEntity entity) async {
//     _activeAxis = null;
//     if (entity == _activeEntity) {
//       return;
//     }
//     if (entity == center) {
//       _activeEntity = null;
//       return;
//     }
//     _visible = true;

//     if (_activeEntity != null) {
//       // await viewer.removeStencilHighlight(_activeEntity!);
//     }
//     _activeEntity = entity;

//     await viewer.setParent(center, entity, preserveScaling: false);
//     _boundingBoxController.sink.add(await viewer.getViewportBoundingBox(x));
//   }

//   Future detach() async {
//     await setVisibility(false);
//   }

//   @override
//   void checkHover(int x, int y) {
//     pick(x, y);
//   }

//   Future pick(int x, int y);

//   Future setVisibility(bool visible);
//   void onPick(void Function(PickResult result) callback);
// }
