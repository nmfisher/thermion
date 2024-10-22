import 'package:vector_math/vector_math_64.dart';

import 'input_handler.dart';

abstract class InputHandlerDelegate {
  Future queue(InputAction action, Vector3? delta);
  Future execute();
}

abstract class VelocityDelegate {
  Vector2? get velocity;

  void updateVelocity(Vector2 delta);

  void startDeceleration();

  void stopDeceleration();

  void dispose() {
    stopDeceleration();
  }
}

abstract class PickDelegate {
  const PickDelegate();
  void pick(Vector2 location);
}
