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

class BoneDriver {
  final String bone;
  final String blendshape;

  late final Vector3 transMin;
  late final Vector3 transMax;
  late final Quaternion rotMin;
  late final Quaternion rotMax;

  BoneDriver(this.bone, this.blendshape, this.rotMin, this.rotMax,
      Vector3? transMin, Vector3? transMax) {
    this.transMin = transMin ?? Vector3.zero();
    this.transMax = transMax ?? Vector3.zero();
  }

  factory BoneDriver.fromJsonObject(dynamic jsonObject) {
    return BoneDriver(
      jsonObject["bone"],
      jsonObject["blendshape"],
      Quaternion.fromFloat32List(Float32List.fromList(jsonObject["rotMin"])),
      Quaternion.fromFloat32List(Float32List.fromList(jsonObject["rotMax"])),
      Vector3.fromFloat32List(Float32List.fromList(jsonObject["transMin"])),
      Vector3.fromFloat32List(Float32List.fromList(jsonObject["transMax"])),
    );
  }

  //
  // Accepts a Float32List containing [numFrames] frames of data for a single morph target weight (for efficiency, this must be unravelled to a single contiguous Float32List).
  // Returns a generator that yields [numFrames] Quaternions, each representing the (weighted) rotation/translation specified by the mapping of this BoneDriver.
  //
  Iterable<Quaternion> transform(List<double> morphTargetFrameData) sync* {
    for (int i = 0; i < morphTargetFrameData.length; i++) {
      var weight = (morphTargetFrameData[i] / 2) + 0.5;

      yield Quaternion(
          rotMin.x + (weight * (rotMax.x - rotMin.x)),
          rotMin.y + (weight * (rotMax.y - rotMin.y)),
          rotMin.z + (weight * (rotMax.z - rotMin.z)),
          1.0);
    }
  }
}
