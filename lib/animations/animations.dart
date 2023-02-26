import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

class BoneAnimation {
  final List<String> boneNames;
  final List<String> meshNames;
  final Float32List frameData;

  BoneAnimation(this.boneNames, this.meshNames, this.frameData);

  List<List> toList() {
    return [boneNames, meshNames, frameData];
  }
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

  late final Float32List morphData;

  MorphAnimation(
      this.meshName, this.morphData, this.morphNames, this.frameLengthInMs);

  int get numMorphWeights => morphNames.length;

  int get numFrames => morphData.length ~/ numMorphWeights;

  final double frameLengthInMs;
}

class Animation {
  final MorphAnimation? morphAnimation;
  final List<BoneAnimation>? boneAnimations;

  Animation({this.morphAnimation, this.boneAnimations});
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

// Animation.from(
//     {required this.meshName,
//     required List<List<double>> morphData,
//     required this.numMorphWeights,
//     this.boneAnimations,
//     required this.numFrames,
//     required this.frameLengthInMs}) {
//   if (morphData.length != numFrames) {
//     throw Exception("Mismatched animation data with frame length");
//   }
// }

//  not directly used, the list of morph targets animated by this [Animation], and may be a subset of the actual morph targets in the asset (and may also be ordered differently).
// // When passed to a [FilamentController], these will be re-mapped appropriately (and any morph targets not provided will be set to zero at each frame).