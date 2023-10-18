import 'package:polyvox_filament/animations/animation_data.dart';
import 'package:vector_math/vector_math.dart';

class AnimationBuilder {
  // BoneAnimationData? BoneAnimationData;
  double _frameLengthInMs = 0;
  double _duration = 0;

  double? _interpMorphStart;
  double? _interpMorphEnd;
  double? _interpMorphStartValue;
  double? _interpMorphEndValue;

  // List<BoneAnimationData>? _BoneAnimationDatas = null;

  String meshName;
  late List<String> availableMorphs;
  late List<int> _morphTargets;

  AnimationBuilder(
      {required this.availableMorphs,
      required this.meshName,
      required int framerate}) {
    _frameLengthInMs = 1000 / framerate;
  }

  MorphAnimationData build() {
    if (availableMorphs.isEmpty == 0 || _duration == 0 || _frameLengthInMs == 0)
      throw Exception();

    int numFrames = _duration * 1000 ~/ _frameLengthInMs;

    final morphData =
        List<double>.filled((numFrames * _morphTargets.length).toInt(), 0.0);

    var frameStart = (_interpMorphStart! * 1000) ~/ _frameLengthInMs;
    var frameEnd = (_interpMorphEnd! * 1000) ~/ _frameLengthInMs;

    for (int i = frameStart; i < frameEnd; i++) {
      var linear = (i - frameStart) / frameEnd;

      var val = ((1 - linear) * _interpMorphStartValue!) +
          (linear * _interpMorphEndValue!);
      for (int j = 0; j < _morphTargets.length; j++) {
        morphData[(i * _morphTargets.length) + j] = val;
      }
    }
    return MorphAnimationData(
        meshName,
        morphData,
        _morphTargets.map((i) => availableMorphs[i]).toList(),
        _morphTargets,
        _frameLengthInMs);
  }

  AnimationBuilder setDuration(double secs) {
    _duration = secs;
    return this;
  }

  AnimationBuilder setMorphTargets(List<String> names) {
    _morphTargets = names.map((name) => availableMorphs.indexOf(name)).toList();
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

    // _BoneAnimationDatas ??= <BoneAnimationData>[];

    // var frameData = List<List<double>>.generate(
    //     numFrames, (index) => boneFrameData.getFrameData(index).toList());

    // var animData = Float32List.fromList(frameData.expand((x) => x).toList());

    // _BoneAnimationDatas!.add(DartBoneAnimationData([boneName], [meshName], animData));

    return this;
  }
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
