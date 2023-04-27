import 'dart:math';

import 'package:polyvox_filament/animations/bone_driver.dart';
import 'package:vector_math/vector_math.dart';

BoneDriver getLiveLinkFaceBoneDrivers(String bone) {
  return BoneDriver(bone, {
    "HeadPitch": Transformation(Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2)),
    "HeadRoll": Transformation(Quaternion.axisAngle(Vector3(0, 0, 1), pi / 2)),
    "HeadYaw": Transformation(Quaternion.axisAngle(Vector3(0, 1, 0), pi / 2)),
  });
}
