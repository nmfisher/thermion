import 'dart:convert';
import 'package:vector_math/vector_math.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

///
/// Some animation data may be specified as blendshape weights (say, between -1 and 1)
/// but at runtime we want to retarget this to drive a bone translation/rotation (say, between -pi/2 and pi/2).
/// A [BoneDriver] is our mechanism for translating the former to the latter, containing:
/// 1) a blendshape name
/// 2) a bone name
/// 3) min/max translation values (corresponding to -1/1 on the blendshape), and
/// 4) min/max rotation values (corresponding to -1/1 on the blendshape)
///

class Transformation {
  final Quaternion rotation;
  late final Vector3 translation;

  Transformation(this.rotation, {Vector3? translation}) {
    this.translation = translation ?? Vector3.zero();
  }
}

class BoneDriver {
  final String bone;
  final Map<String, Transformation>
      transformations; // maps a blendshape key to a Transformation

  BoneDriver(this.bone, this.transformations);

  //
  // Accepts a Float32List containing [numFrames] frames of data for a single morph target weight (for efficiency, this must be unravelled to a single contiguous Float32List).
  // Returns a generator that yields [numFrames] Quaternions, each representing the (weighted) rotation/translation specified by the mapping of this BoneDriver.
  //
  Iterable<Quaternion> transform(
      Map<String, List<double>> morphTargetFrameData) sync* {
    assert(setEquals(
        morphTargetFrameData.keys.toSet(), transformations.keys.toSet()));
    var numFrames = morphTargetFrameData.values.first.length;
    assert(morphTargetFrameData.values.every((x) => x.length == numFrames));
    for (int frameNum = 0; frameNum < numFrames; frameNum++) {
      var rotations = transformations.keys.map((blendshape) {
        var weight = morphTargetFrameData[blendshape]![frameNum];
        var rotation = transformations[blendshape]!.rotation.clone();
        rotation.x *= weight;
        rotation.y *= weight;
        rotation.z *= weight;
        rotation.w = 1;

        return rotation;
      }).toList();

      if (frameNum == 0) {
        print(rotations);
      }

      var result = rotations.fold(
          rotations.first, (Quaternion a, Quaternion b) => a + b);
      result.w = 1;
      print("RESULT $result");
      yield result;
      // .normalized();
      // todo - bone translations
    }
  }

  factory BoneDriver.fromJsonObject(dynamic jsonObject) {
    throw Exception("TODO");
    //   return BoneDriver(
    //     jsonObject["bone"],
    //     Map<String,Transformation>.fromIterable(jsonObject["blendshape"].map((bsName, quats) {
    //       var q = quats.map(())
    //       MapEntry(k,
  }
}


 

  // }
      // yield Quaternion(
      //     rotMin.x + (weight * (rotMax.x - rotMin.x)),
      //     rotMin.y + (weight * (rotMax.y - rotMin.y)),
      //     rotMin.z + (weight * (rotMax.z - rotMin.z)),
      //     1.0);