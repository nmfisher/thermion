import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Plane', () {
    var plane = Plane()..setFromComponents(1, 0, 0, 2);
    print(plane.distanceToVector3(Vector3(-1, 0, 0)));
  });

  test('Check if point is inside frustum', () {
    var frustum = Frustum();
    frustum.plane0.setFromComponents(-0.868, 0, 0.49, 0);
    frustum.plane1.setFromComponents(0.868, 0, 0.49, 0);
    frustum.plane2.setFromComponents(0, -0.919, 0.39, 0);
    frustum.plane3.setFromComponents(0, 0.919, 0.39, 0);
    frustum.plane4.setFromComponents(0, 0, -1, -999.88);
    frustum.plane5.setFromComponents(0, 0, 1, 0.05);

    var point = Vector3(0, 0, -1);

    print(frustum.plane0.distanceToVector3(point));
    print(frustum.plane1.distanceToVector3(point));

    print(frustum.plane2.distanceToVector3(point));

    print(frustum.plane3.distanceToVector3(point));

    print(frustum.plane4.distanceToVector3(point));

    print(frustum.plane5.distanceToVector3(point));

    print(frustum.containsVector3(point));
  });

  test("Lukas test", () {
    final frustum = Frustum();
    //left
    frustum.plane0.setFromComponents(-1.0, 0, 0, 1);
    //right
    frustum.plane1.setFromComponents(1.0, 0, 0, 2.0);
    //bottom
    frustum.plane2.setFromComponents(0, -1, 0, 1);
    //top
    frustum.plane3.setFromComponents(0, 1, 0, 1);
    //far
    frustum.plane4.setFromComponents(0, 0, -1, 1);
    //near
    frustum.plane5.setFromComponents(0, 0, 1, 1);

    // vector3
    final point = Vector3(-0.5, 0, 0);

    print(frustum.plane0.distanceToVector3(point));
    print(frustum.plane1.distanceToVector3(point));

    print(frustum.plane2.distanceToVector3(point));

    print(frustum.plane3.distanceToVector3(point));

    print(frustum.plane4.distanceToVector3(point));

    print(frustum.plane5.distanceToVector3(point));

    print(frustum.containsVector3(point));
  });
}
