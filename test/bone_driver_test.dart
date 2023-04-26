import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyvox_filament/animations/bone_driver.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('BoneDriver', () {
    test('constructor sets correct values', () {
      Quaternion rotMin = Quaternion.identity();
      Quaternion rotMax = Quaternion.axisAngle(Vector3(1, 0, 0), 0.5);
      Vector3 transMin = Vector3.zero();
      Vector3 transMax = Vector3(1, 1, 1);

      BoneDriver boneDriver = BoneDriver(
          'bone1', 'blendshape1', rotMin, rotMax, transMin, transMax);

      expect(boneDriver.bone, 'bone1');
      expect(boneDriver.blendshape, 'blendshape1');
      expect(boneDriver.rotMin, rotMin);
      expect(boneDriver.rotMax, rotMax);
      expect(boneDriver.transMin, transMin);
      expect(boneDriver.transMax, transMax);
    });

    test('fromJsonObject creates BoneDriver instance correctly', () {
      dynamic jsonObject = {
        "bone": "bone1",
        "blendshape": "blendshape1",
        "rotMin": Quaternion.identity().storage,
        "rotMax": Quaternion.axisAngle(Vector3(1, 0, 0), 0.5).storage,
        "transMin": Vector3.zero().storage,
        "transMax": Vector3(1, 1, 1).storage
      };

      BoneDriver boneDriver = BoneDriver.fromJsonObject(jsonObject);

      expect(boneDriver.bone, 'bone1');
      expect(boneDriver.blendshape, 'blendshape1');
      expect(boneDriver.rotMin.absoluteError(Quaternion.identity()), 0);
      expect(
          boneDriver.rotMax
              .absoluteError(Quaternion.axisAngle(Vector3(1, 0, 0), 0.5)),
          0);
      expect(boneDriver.transMin.absoluteError(Vector3.zero()), 0);
      expect(boneDriver.transMax.absoluteError(Vector3(1, 1, 1)), 0);
    });

    test('transform generates correct Quaternions', () {
      Quaternion rotMin = Quaternion.identity();
      Quaternion rotMax = Quaternion.axisAngle(Vector3(1, 0, 0), 0.5);
      BoneDriver boneDriver =
          BoneDriver('bone1', 'blendshape1', rotMin, rotMax, null, null);

      List<double> morphTargetFrameData = [-1, 0, 1];
      List<Quaternion> expectedResult = [
        Quaternion(rotMin.x, rotMin.y, rotMin.z, 1.0),
        Quaternion((rotMin.x + rotMax.x) / 2, (rotMin.y + rotMax.y) / 2,
            (rotMin.z + rotMax.z) / 2, 1.0),
        Quaternion(rotMax.x, rotMax.y, rotMax.z, 1.0),
      ];

      Iterable<Quaternion> result = boneDriver.transform(morphTargetFrameData);
      List<Quaternion> resultAsList = result.toList();
      expect(resultAsList.length, expectedResult.length);

      for (int i = 0; i < expectedResult.length; i++) {
        expect(resultAsList[i].absoluteError(expectedResult[i]), 0);
      }
    });
  });
}
