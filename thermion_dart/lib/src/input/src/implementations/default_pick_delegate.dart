import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultPickDelegate extends PickDelegate {
  final ThermionViewer viewer;

  const DefaultPickDelegate(this.viewer);

  @override
  void pick(Vector2 location) {
    viewer.pick(location.x.toInt(), location.y.toInt());
  }
}
