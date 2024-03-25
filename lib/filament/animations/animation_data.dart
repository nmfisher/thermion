import 'package:vector_math/vector_math_64.dart';

///
/// Specifies frame data (i.e. weights) to animate the morph targets contained in [morphTargets] under a mesh named [mesh].
/// [data] is laid out as numFrames x numMorphTargets.
/// Each frame is [numMorphTargets] in length, where the index of each weight corresponds to the respective index in [morphTargets].
/// [morphTargets] must be some subset of the actual morph targets under [mesh] (though the order of these does not need to match).
///
class MorphAnimationData {
  final List<String> meshNames;
  final List<String> morphTargets;

  final List<double> data;

  MorphAnimationData(
      this.meshNames, this.data, this.morphTargets, this.frameLengthInMs) {
    assert(data.length == morphTargets.length * numFrames);
  }

  int get numMorphTargets => morphTargets.length;

  int get numFrames => data.length ~/ numMorphTargets;

  final double frameLengthInMs;

  Iterable<double> getData(String morphName) sync* {
    int index = morphTargets.indexOf(morphName);
    if (index == -1) {
      throw Exception("No data for morph $morphName");
    }
    for (int i = 0; i < numFrames; i++) {
      yield data[(i * numMorphTargets) + index];
    }
  }
}

///
/// Model class for bone animation frame data.
/// To create dynamic/runtime bone animations (as distinct from animations embedded in a glTF asset), create an instance containing the relevant
/// data and pass to the [setBoneAnimation] method on a [FilamentController].
/// [frameData] is laid out as [locX, locY, locZ, rotW, rotX, rotY, rotZ]
///
class BoneAnimationData {
  final List<String> bones;
  final List<String> meshNames;
  final List<List<Quaternion>> rotationFrameData;
  final List<List<Vector3>> translationFrameData;
  double frameLengthInMs;
  final bool isModelSpace;
  BoneAnimationData(this.bones, this.meshNames, this.rotationFrameData,
      this.translationFrameData, this.frameLengthInMs,
      {this.isModelSpace = false});

  int get numFrames => rotationFrameData.length;

  BoneAnimationData frame(int frame) {
    return BoneAnimationData(bones, meshNames, [rotationFrameData[frame]],
        [translationFrameData[frame]], frameLengthInMs,
        isModelSpace: isModelSpace);
  }
}
