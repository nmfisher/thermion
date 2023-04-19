import 'package:polyvox_filament/animations/animations.dart';
import 'package:tuple/tuple.dart';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

class AnimationBuilder {
  DartBoneAnimation? dartBoneAnimation;
  double _frameLengthInMs = 0;
  double _duration = 0;
  int _numMorphWeights = 0;

  double? _interpMorphStart;
  double? _interpMorphEnd;
  double? _interpMorphStartValue;
  double? _interpMorphEndValue;

  List<DartBoneAnimation>? _dartBoneAnimations = null;

  Tuple2<MorphAnimation, List<DartBoneAnimation>> build(
      String meshName, List<String> morphNames) {
    if (_numMorphWeights == 0 || _duration == 0 || _frameLengthInMs == 0)
      throw Exception();

    int numFrames = _duration * 1000 ~/ _frameLengthInMs;

    final morphData = Float32List((numFrames * _numMorphWeights).toInt());

    var frameStart = (_interpMorphStart! * 1000) ~/ _frameLengthInMs;
    var frameEnd = (_interpMorphEnd! * 1000) ~/ _frameLengthInMs;

    for (int i = frameStart; i < frameEnd; i++) {
      var linear = (i - frameStart) / frameEnd;

      var val = ((1 - linear) * _interpMorphStartValue!) +
          (linear * _interpMorphEndValue!);
      for (int j = 0; j < _numMorphWeights; j++) {
        morphData[(i * _numMorphWeights) + j] = val;
      }
    }

    var morphAnimation =
        MorphAnimation(meshName, morphData, morphNames, _frameLengthInMs);

    return Tuple2<MorphAnimation, List<DartBoneAnimation>>(
        morphAnimation, _dartBoneAnimations!);
  }

  AnimationBuilder setFramerate(int framerate) {
    _frameLengthInMs = 1000 / framerate;
    return this;
  }

  AnimationBuilder setDuration(double secs) {
    _duration = secs;
    return this;
  }

  AnimationBuilder setNumMorphWeights(int numMorphWeights) {
    _numMorphWeights = numMorphWeights;
    return this;
  }

  AnimationBuilder interpolateMorphWeights(
      double start, double end, double startValue, double endValue) {
    this._interpMorphStart = start;
    this._interpMorphEnd = end;
    this._interpMorphStartValue = startValue;
    this._interpMorphEndValue = endValue;
    return this;
  }

  AnimationBuilder interpolateBoneTransform(
      String boneName,
      String meshName,
      double start,
      double end,
      Vector3 transStart,
      Vector3 transEnd,
      Quaternion quatStart,
      Quaternion quatEnd) {
    var translations = <Vector3>[];
    var quats = <Quaternion>[];
    var frameStart = (start * 1000) ~/ _frameLengthInMs;
    var frameEnd = (end * 1000) ~/ _frameLengthInMs;
    int numFrames = _duration * 1000 ~/ _frameLengthInMs;
    if (frameEnd > numFrames) {
      throw Exception();
    }

    for (int i = 0; i < numFrames; i++) {
      if (i >= frameStart && i < frameEnd) {
        var linear = (i - frameStart) / (frameEnd - frameStart);

        translations.add(Vector3(
          ((1 - linear) * transStart.x) + (linear * transEnd.x),
          ((1 - linear) * transStart.y) + (linear * transEnd.y),
          ((1 - linear) * transStart.z) + (linear * transEnd.z),
        ));

        quats.add(Quaternion(
          ((1 - linear) * quatStart.x) + (linear * quatEnd.x),
          ((1 - linear) * quatStart.y) + (linear * quatEnd.y),
          ((1 - linear) * quatStart.z) + (linear * quatEnd.z),
          ((1 - linear) * quatStart.w) + (linear * quatEnd.w),
        ));
      } else {
        translations.add(Vector3.zero());
        quats.add(Quaternion.identity());
      }
    }

    throw Exception();

    // var boneFrameData = BoneTransformFrameData(translations, quats);

    // _DartBoneAnimations ??= <DartBoneAnimation>[];

    // var frameData = List<List<double>>.generate(
    //     numFrames, (index) => boneFrameData.getFrameData(index).toList());

    // var animData = Float32List.fromList(frameData.expand((x) => x).toList());

    // _DartBoneAnimations!.add(DartDartBoneAnimation([boneName], [meshName], animData));

    return this;
  }
}
