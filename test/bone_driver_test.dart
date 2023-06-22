import 'package:flutter_test/flutter_test.dart';
import 'package:polyvox_filament/animations/bone_driver.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('BoneDriver', () {
    test(
        'transform should yield correct Quaternions for given morphTargetFrameData',
        () {
      final bone = 'bone1';
      final transformations = {
        'blendshape1': Transformation(Quaternion(1, 0, 0, 1)),
        'blendshape2': Transformation(Quaternion(0, 1, 0, 1)),
      };
      final morphTargetFrameData = <String, List<double>>{
        'blendshape1': [0.5, -0.5],
        'blendshape2': [-1, 1],
      };
      final boneDriver = BoneDriver(bone, transformations);

      final result = boneDriver.transform(morphTargetFrameData).toList();

      expect(result.length, 2);
      expect(result[0].x, -0.5);
      expect(result[0].y, 0);
      expect(result[0].z, -0.5);
      expect(result[0].w, 0);
      expect(result[1].x, 0.5);
      expect(result[1].y, 0);
      expect(result[1].z, 0.5);
      expect(result[1].w, 0);
    });

    test(
        'transform should throw AssertionError when morphTargetFrameData keys do not match transformations keys',
        () {
      final bone = 'bone1';
      final transformations = {
        'blendshape1': Transformation(Quaternion(1, 0, 0, 0)),
        'blendshape2': Transformation(Quaternion(0, 1, 0, 0)),
      };
      final morphTargetFrameData = <String, List<double>>{
        'blendshape1': [0.5, -0.5],
        'blendshape3': [-1, 1],
      };
      final boneDriver = BoneDriver(bone, transformations);

      expect(() => boneDriver.transform(morphTargetFrameData),
          throwsA(isA<AssertionError>()));
    });

    test(
        'transform should throw AssertionError when morphTargetFrameData values lengths do not match',
        () {
      final bone = 'bone1';
      final transformations = {
        'blendshape1': Transformation(Quaternion(1, 0, 0, 0)),
        'blendshape2': Transformation(Quaternion(0, 1, 0, 0)),
      };
      final morphTargetFrameData = <String, List<double>>{
        'blendshape1': [0.5, -0.5],
        'blendshape2': [-1],
      };
      final boneDriver = BoneDriver(bone, transformations);

      expect(() => boneDriver.transform(morphTargetFrameData),
          throwsA(isA<AssertionError>()));
    });
  });
}
