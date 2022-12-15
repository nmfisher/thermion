class Vec3 {
  final double x;
  final double y;
  final double z;

  Vec3({this.x = 0, this.y = 0, this.z = 0});

  factory Vec3.from(List<double> vals) =>
      Vec3(x: vals[0], y: vals[1], z: vals[2]);
}

class Quaternion {
  double x = 0;
  double y = 0;
  double z = 0;
  double w = 1;

  Quaternion({this.x = 0, this.y = 0, this.z = 0, this.w = 1.0});

  factory Quaternion.from(List<double> vals) =>
      Quaternion(x: vals[0], y: vals[1], z: vals[2], w: vals[3]);
}

class BoneTransform {
  final List<Vec3> translations;
  final List<Quaternion> quaternions;

  ///
  /// The length of [translations] and [quaternions] must be the same;
  /// each entry represents the Vec3/Quaternion for the given frame.
  ///
  BoneTransform(this.translations, this.quaternions) {
    if (translations.length != quaternions.length) {
      throw Exception("Length of translation/quaternion frames must match");
    }
    // for (int i = 0; i < quaternions.length; i++) {
    //   _frameData.add(translations[i].x);
    //   _frameData.add(translations[i].y);
    //   _frameData.add(translations[i].z);
    //   _frameData.add(quaternions[i].x);
    //   _frameData.add(quaternions[i].y);
    //   _frameData.add(quaternions[i].z);
    //   _frameData.add(quaternions[i].w);
    // }
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

class BoneAnimation {
  final List<BoneTransform> boneTransforms;
  final List<String> boneNames;
  final List<String> meshNames;

  final int numFrames;

  BoneAnimation(
      this.boneTransforms, this.boneNames, this.meshNames, this.numFrames);

  Iterable<double> toFrameData() sync* {
    for (int i = 0; i < numFrames; i++) {
      for (int j = 0; j < boneTransforms.length; j++) {
        yield* boneTransforms[j].getFrameData(i);
      }
    }
  }
}
