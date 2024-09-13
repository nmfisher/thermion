import 'dart:ui';

import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultPanCameraDelegate implements PanCameraDelegate {
  final ThermionViewer viewer;

  DefaultPanCameraDelegate(this.viewer);

  @override
  Future<void> panCamera(Offset delta, Vector2? velocity) async {
    // Implement panning logic here
    // This is a placeholder implementation
    print("Panning camera by $delta");
  }
}