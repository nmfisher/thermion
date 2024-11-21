import 'dart:async';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultPickDelegate extends PickDelegate {
  final ThermionViewer viewer;

  DefaultPickDelegate(this.viewer);

  final _picked = StreamController<ThermionEntity>();
  Stream<ThermionEntity> get picked => _picked.stream;

  Future dispose() async {
    _picked.close();
  }

  @override
  void pick(Vector2 location) {
    viewer.pick(location.x.toInt(), location.y.toInt(), (result) {
      _picked.sink.add(result.entity);
    });
  }
}
