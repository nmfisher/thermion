import 'package:vector_math/vector_math_64.dart';

enum Axis {
  X(const [1.0, 0.0, 0.0]),
  Y(const [0.0, 1.0, 0.0]),
  Z(const [0.0, 0.0, 1.0]);

  const Axis(this.vector);

  final List<double> vector;

  Vector3 asVector() => Vector3(vector[0], vector[1], vector[2]);
}