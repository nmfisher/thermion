// import 'dart:async';

// import 'package:thermion_dart/thermion_dart.dart';
// import 'package:vector_math/vector_math_64.dart';

// class GizmoPickDelegate extends PickDelegate {
//   final ThermionViewer viewer;
//   late final GizmoAsset translationGizmo;

//   GizmoPickDelegate(this.viewer) {
//     initialize();
//   }

//   bool _initialized = false;
//   Future initialize() async {
//     if (_initialized) {
//       throw Exception("Already initialized");
//     }
//     final view = await viewer.getViewAt(0);
//     translationGizmo = await viewer.createGizmo(view, GizmoType.translation);
//     await translationGizmo.addToScene();
//     _initialized = true;
//   }

//   final _picked = StreamController<ThermionEntity>();
//   Stream<ThermionEntity> get picked => _picked.stream;

//   Future dispose() async {
//     _picked.close();
//   }

//   @override
//   void pick(Vector2 location) {
//     if (!_initialized) {
//       return;
//     }
//     viewer.pick(location.x.toInt(), location.y.toInt(), (result) {
//       translationGizmo.attach(result.entity);
//     });
//   }
// }
