import 'animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Animation {
  final Float32List morphWeights;
  final int numMorphWeights;

  final int numFrames;
  final double frameLengthInMs;

  final List<String> boneNames;
  final List<String> meshNames;

  final Float32List boneTransforms;

  Animation(this.morphWeights, this.numMorphWeights, this.boneTransforms,
      this.boneNames, this.meshNames, this.numFrames, this.frameLengthInMs);
}

class AnimationBuilder {
  BoneAnimation? boneAnimation;
  double _frameLengthInMs = 0;
  double _duration = 0;
  int _numMorphWeights = 0;

  double? _interpMorphStart;
  double? _interpMorphEnd;
  double? _interpMorphStartValue;
  double? _interpMorphEndValue;

  final List<String> _boneNames = [];
  final List<String> _meshNames = [];
  final List<BoneTransform> _boneTransforms = [];

  Animation build() {
    if (_numMorphWeights == 0 || _duration == 0 || _frameLengthInMs == 0)
      throw Exception();

    int numFrames = _duration * 1000 ~/ _frameLengthInMs;

    final _morphWeights = Float32List((numFrames * _numMorphWeights).toInt());

    var frameStart = (_interpMorphStart! * 1000) ~/ _frameLengthInMs;
    var frameEnd = (_interpMorphEnd! * 1000) ~/ _frameLengthInMs;

    for (int i = frameStart; i < frameEnd; i++) {
      var linear = (i - frameStart) / frameEnd;

      var val = ((1 - linear) * _interpMorphStartValue!) +
          (linear * _interpMorphEndValue!);
      for (int j = 0; j < _numMorphWeights; j++) {
        _morphWeights[(i * _numMorphWeights) + j] = val;
      }
    }

    print(
        "Created morphWeights of size ${_morphWeights.length} (${_morphWeights.lengthInBytes} for ${numFrames} frames");

    final boneTransforms = Float32List(numFrames * _boneTransforms.length * 7);
    print(
        "Creating bone transforms of size ${numFrames * _boneTransforms.length * 7}");
    for (int i = 0; i < numFrames; i++) {
      for (int j = 0; j < _boneTransforms.length; j++) {
        var frameData = _boneTransforms[j].getFrameData(i).toList();
        var rngStart = ((i * _boneTransforms.length) + j) * 7;
        var rngEnd = rngStart + 7;
        boneTransforms.setRange(rngStart, rngEnd, frameData);
      }
      print(
          "frameData for frame $i ${boneTransforms.sublist(i * _boneTransforms.length * 7, (i * _boneTransforms.length * 7) + 7)}");
    }

    return Animation(_morphWeights, _numMorphWeights, boneTransforms,
        _boneNames, _meshNames, numFrames, _frameLengthInMs);
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
      Vec3 transStart,
      Vec3 transEnd,
      Quaternion quatStart,
      Quaternion quatEnd) {
    var translations = <Vec3>[];
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

        translations.add(Vec3(
          x: ((1 - linear) * transStart.x) + (linear * transEnd.x),
          y: ((1 - linear) * transStart.y) + (linear * transEnd.y),
          z: ((1 - linear) * transStart.z) + (linear * transEnd.z),
        ));

        quats.add(Quaternion(
          x: ((1 - linear) * quatStart.x) + (linear * quatEnd.x),
          y: ((1 - linear) * quatStart.y) + (linear * quatEnd.y),
          z: ((1 - linear) * quatStart.z) + (linear * quatEnd.z),
          w: ((1 - linear) * quatStart.w) + (linear * quatEnd.w),
        ));
      } else {
        translations.add(Vec3());
        quats.add(Quaternion());
      }
    }

    _boneTransforms.add(BoneTransform(translations, quats));

    _boneNames.add(boneName);
    _meshNames.add(meshName);

    return this;
  }
}
