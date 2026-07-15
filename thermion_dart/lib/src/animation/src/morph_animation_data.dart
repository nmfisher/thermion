import 'dart:typed_data';
import 'dart:math';

///
/// A generic interface for storing/retrieving morph target animation
/// (aka "blendshape") frame data.
/// [morphTargets] contains the names of each morph target/blendshape.
/// Each value in [data] represents one frame.
/// Each frame consists of N weights (usually between 0.0 and 1.0), representing
/// the weight of the morph target/blendshape at the same index in [morphTargets].
///
class MorphAnimationData {
  final List<String> morphTargets;
  final Float32List data;
  final double frameLengthInMs;

  MorphAnimationData(
    this.data,
    this.morphTargets, {
    required this.frameLengthInMs,
  }) {
    assert(morphTargets.isNotEmpty);
    assert(numFrames > 0);
  }

  int get numMorphTargets => morphTargets.length;

  int get numFrames => data.length ~/ numMorphTargets;

  int get durationInMs => (numFrames * frameLengthInMs).toInt();

  MorphAnimationData subset(List<String> newMorphTargets) {
    late List<int> indices = <int>[];
    for (final morphTarget in newMorphTargets) {
      var index = this.morphTargets.indexOf(morphTarget);
      if (index == -1) {
        throw Exception("Failed to find morph target $morphTarget");
      }
      indices.add(index);
    }

    var newData = Float32List(numFrames * indices.length);

    for (int frameNum = 0; frameNum < numFrames; frameNum++) {
      for (int newIdx = 0; newIdx < indices.length; newIdx++) {
        var oldIdx = indices[newIdx];
        newData[(frameNum * indices.length) + newIdx] =
            data[(frameNum * this.morphTargets.length) + oldIdx];
      }
    }
    return MorphAnimationData(
      newData,
      newMorphTargets,
      frameLengthInMs: frameLengthInMs,
    );
  }

  String toCSV() {
    var sb = StringBuffer("Timestamp,BlendshapeCount,");
    sb.writeln(morphTargets.join(","));
    int frameNum = 0;
    for (int i = 0; i < data.length ~/ morphTargets.length; i++) {
      var frame = data.sublist(
        i * morphTargets.length,
        (i + 1) * morphTargets.length,
      );
      sb.writeln("$frameNum,$numMorphTargets," + frame.join(','));
      frameNum++;
    }
    return sb.toString();
  }

  MorphAnimationData frame(int start, int end) {
    var frameData = Float32List.sublistView(
      this.data,
      start * numMorphTargets,
      end * numMorphTargets,
    );
    return MorphAnimationData(
      frameData,
      morphTargets,
      frameLengthInMs: frameLengthInMs,
    );
  }

  MorphAnimationData rename(List<String> morphTargets) {
    return MorphAnimationData(
      data,
      morphTargets,
      frameLengthInMs: frameLengthInMs,
    );
  }

  void scale(double scale) {
    if (scale == 1.0) {
      return;
    }
    for (int i = 0; i < data.length; i++) {
      data[i] = max(0.0, min(1.0, data[i] * scale));
    }
  }

  static MorphAnimationData merge(List<MorphAnimationData> animations) {
    var totalSize = 0;
    for (final animation in animations) {
      totalSize += animation.data.length;
    }
    var mergedData = Float32List(totalSize);
    var offset = 0;
    for (final animation in animations) {
      mergedData.setRange(
        offset,
        offset + animation.data.length,
        animation.data,
      );
      offset += animation.data.length;
    }
    return MorphAnimationData(
      mergedData,
      animations.first.morphTargets,
      frameLengthInMs: animations.first.frameLengthInMs,
    );
  }

  MorphAnimationData filter({
    double processNoise = 1e-4,
    double measurementNoise = 1e-1,
    double? initialEstimate,
  }) {
    Float32List filteredData = Float32List(data.length);

    for (int morphTargetIndex = 0;
        morphTargetIndex < numMorphTargets;
        morphTargetIndex++) {
      double estimate = initialEstimate ?? data[morphTargetIndex];
      double errorEstimate = 1.0;

      for (int frameIndex = 0; frameIndex < numFrames; frameIndex++) {
        int dataIndex = frameIndex * numMorphTargets + morphTargetIndex;
        double measurement = data[dataIndex];

        // Prediction step
        double predictedEstimate = estimate;
        double predictedErrorEstimate = errorEstimate + processNoise;

        // Update step
        double kalmanGain = predictedErrorEstimate /
            (predictedErrorEstimate + measurementNoise);
        estimate =
            predictedEstimate + kalmanGain * (measurement - predictedEstimate);
        errorEstimate = (1 - kalmanGain) * predictedErrorEstimate;

        filteredData[dataIndex] = estimate;
      }
    }

    return MorphAnimationData(
      filteredData,
      morphTargets,
      frameLengthInMs: frameLengthInMs,
    );
  }

  MorphAnimationData resample(double newFrameRate) {
    if (newFrameRate == 1000 / frameLengthInMs) {
      return this;
    }

    double factor = newFrameRate / (1000 / frameLengthInMs);
    int expectedLength = (numFrames * factor).round();

    List<double> x = List.generate(expectedLength, (i) => i / newFrameRate);
    List<double> xp = List.generate(
      numFrames,
      (i) => i * frameLengthInMs / 1000,
    );

    Float32List newData = Float32List(expectedLength * numMorphTargets);

    for (int morphTargetIndex = 0;
        morphTargetIndex < numMorphTargets;
        morphTargetIndex++) {
      List<double> yp = List.generate(
        numFrames,
        (i) => data[i * numMorphTargets + morphTargetIndex],
      );

      for (int i = 0; i < expectedLength; i++) {
        double t = x[i];
        int j = xp.indexWhere((xpValue) => xpValue > t);
        if (j == -1) {
          j = numFrames - 1;
        } else if (j > 0) {
          j--;
        }

        double t0 = xp[j];
        double t1 = j < numFrames - 1 ? xp[j + 1] : t0;
        double y0 = yp[j];
        double y1 = j < numFrames - 1 ? yp[j + 1] : y0;

        double interpolatedValue;
        if (t1 == t0) {
          interpolatedValue = y0;
        } else {
          interpolatedValue = y0 + (y1 - y0) * (t - t0) / (t1 - t0);
        }

        newData[i * numMorphTargets + morphTargetIndex] = interpolatedValue;
      }
    }

    return MorphAnimationData(
      newData,
      morphTargets,
      frameLengthInMs: 1000 / newFrameRate,
    );
  }
}
