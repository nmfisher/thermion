import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

class DartBoneAnimation {
  final String boneName;
  final String meshName;
  final Float32List frameData;
  double frameLengthInMs;
  DartBoneAnimation(
      this.boneName, this.meshName, this.frameData, this.frameLengthInMs);
}

//
// Frame weights for the morph targets specified in [morphNames] attached to mesh [meshName].
// morphData is laid out as numFrames x numMorphTargets
// where the weights are in the same order as [morphNames].
// [morphNames] must be provided but is not used directly; this is only used to check that the eventual asset being animated contains the same morph targets in the same order.
//
class MorphAnimation {
  final String meshName;
  final List<String> morphNames;

  final Float32List data;

  MorphAnimation(
      this.meshName, this.data, this.morphNames, this.frameLengthInMs) {
    assert(data.length == morphNames.length * numFrames);
  }

  int get numMorphWeights => morphNames.length;

  int get numFrames => data.length ~/ numMorphWeights;

  final double frameLengthInMs;
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
