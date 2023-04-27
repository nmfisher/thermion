//
// Frame weights for the morph targets specified in [morphNames] attached to mesh [meshName].
// morphData is laid out as numFrames x numMorphTargets
// where the weights are in the same order as [morphNames].
// [morphNames] must be provided but is not used directly; this is only used to check that the eventual asset being animated contains the same morph targets in the same order.
//
import 'dart:typed_data';

class MorphAnimationData {
  final String meshName;
  final List<String> morphNames;

  final Float32List data;

  MorphAnimationData(
      this.meshName, this.data, this.morphNames, this.frameLengthInMs) {
    assert(data.length == morphNames.length * numFrames);
  }

  int get numMorphWeights => morphNames.length;

  int get numFrames => data.length ~/ numMorphWeights;

  final double frameLengthInMs;

  Iterable<double> getData(String morphName) sync* {
    int index = morphNames.indexOf(morphName);
    for (int i = 0; i < numFrames; i++) {
      yield data[(i * numMorphWeights) + index];
    }
  }
}
