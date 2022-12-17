import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

// class Vec3 {
//   final double x;
//   final double y;
//   final double z;

//   Vec3({this.x = 0, this.y = 0, this.z = 0});

//   factory Vec3.from(List<double> vals) =>
//       Vec3(x: vals[0], y: vals[1], z: vals[2]);
// }

// class Quaternion {
//   double x = 0;
//   double y = 0;
//   double z = 0;
//   double w = 1;

//   Quaternion({this.x = 0, this.y = 0, this.z = 0, this.w = 1.0});

//   factory Quaternion.from(List<double> vals) =>
//       Quaternion(x: vals[0], y: vals[1], z: vals[2], w: vals[3]);
// }

class BoneAnimation {
  final List<String> boneNames;
  final List<String> meshNames;
  final Float32List frameData;

  BoneAnimation(this.boneNames, this.meshNames, this.frameData);

  List<List> toList() {
    return [boneNames, meshNames, frameData];
  }
}

class Animation {
  late final Float32List? morphData;
  final int numMorphWeights;

  final int numFrames;
  final double frameLengthInMs;

  final List<BoneAnimation>? boneAnimations;

  Animation(this.morphData, this.numMorphWeights, this.boneAnimations,
      this.numFrames, this.frameLengthInMs) {
    if (morphData != null && morphData!.length != numFrames * numMorphWeights) {
      throw Exception("Mismatched animation data with frame length");
    }
  }

  Animation.from(
      {required List<List<double>> morphData,
      required this.numMorphWeights,
      this.boneAnimations,
      required this.numFrames,
      required this.frameLengthInMs}) {
    if (morphData.length != numFrames) {
      throw Exception("Mismatched animation data with frame length");
    }
    this.morphData = Float32List(numMorphWeights * numFrames);
    for (int i = 0; i < numFrames; i++) {
      this.morphData!.setRange((i * numMorphWeights),
          (i * numMorphWeights) + numMorphWeights, morphData[i]);
    }
  }
}

class BoneTransformFrameData {
  final List<Vector3> translations;
  final List<Quaternion> quaternions;

  ///
  /// The length of [translations] and [quaternions] must be the same;
  /// each entry represents the Vec3/Quaternion for the given frame.
  ///
  BoneTransformFrameData(this.translations, this.quaternions) {
    if (translations.length != quaternions.length) {
      throw Exception("Length of translation/quaternion frames must match");
    }
  }

  Iterable<double> getFrameData(int frame) sync* {
    yield translations[frame].x;
    yield translations[frame].y;
    yield translations[frame].z;
    yield quaternions[frame].x;
    yield quaternions[frame].y;
    yield quaternions[frame].z;
    yield quaternions[frame].w;
  }
}
