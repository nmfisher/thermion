//
// Frame weights for the morph targets specified in [morphNames] attached to mesh [meshName].
// morphData is laid out as numFrames x numMorphTargets
// where the weights are in the same order as [morphNames].
// [morphNames] must be provided but is not used directly; this is only used to check that the eventual asset being animated contains the same morph targets in the same order.
//
import 'dart:typed_data';

class MorphAnimationData {
  final String meshName;
  final List<String> animatedMorphNames;
  final List<int> animatedMorphIndices;

  final List<double> data;

  MorphAnimationData(this.meshName, this.data, this.animatedMorphNames,
      this.animatedMorphIndices, this.frameLengthInMs) {
    assert(data.length == animatedMorphNames.length * numFrames);
  }

  int get numMorphTargets => animatedMorphNames.length;

  int get numFrames => data.length ~/ numMorphTargets;

  final double frameLengthInMs;

  Iterable<double> getData(String morphName) sync* {
    int index = animatedMorphNames.indexOf(morphName);
    for (int i = 0; i < numFrames; i++) {
      yield data[(i * numMorphTargets) + index];
    }
  }
}
