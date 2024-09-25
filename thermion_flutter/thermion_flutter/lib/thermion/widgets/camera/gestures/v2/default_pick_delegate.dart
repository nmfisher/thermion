import 'dart:ui';

import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';

class DefaultPickDelegate extends PickDelegate {
  final ThermionViewer _viewer;

  const DefaultPickDelegate(this._viewer);

  @override
  void pick(Offset location) {
    _viewer.pick(location.dx.toInt(), location.dy.toInt());
  }
}
