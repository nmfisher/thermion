import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/bone_driver.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';
import 'package:vector_math/vector_math.dart';

///
/// A class for loading animation data from a single CSV and allocating between morph/bone animation.
///
class DynamicAnimation {
  final MorphAnimationData? morphAnimation;
  final List<BoneAnimationData> boneAnimation;

  factory DynamicAnimation.load(String? meshName, String csvPath,
      {List<BoneDriver>? boneDrivers,
      List<String>? boneMeshes,
      String? boneDriverConfigPath,
      double? framerate}) {
    // create a MorphAnimationData instance from the given CSV
    var llf = _loadLiveLinkFaceCSV(csvPath);
    var frameLengthInMs = 1000 / (framerate ?? 60.0);
    var morphNames = llf.item1;

    if (boneDrivers != null) {
      morphNames = morphNames
          .where((name) =>
              boneDrivers!.any((element) => element.bone == name) == false)
          .toList();
    }

    var morphAnimationData = MorphAnimationData(
        meshName ?? "NULL",
        llf.item2,
        morphNames,
        List<int>.generate(morphNames.length, (index) => index),
        frameLengthInMs);

    final boneAnimations = <BoneAnimationData>[];

    // if applicable, load the bone driver config
    if (boneDriverConfigPath != null) {
      if (boneDrivers != null) {
        throw Exception(
            "Specify either boneDrivers, or the config path, not both");
      }
      boneDrivers = [
        json
            .decode(File(boneDriverConfigPath).readAsStringSync())
            .map(BoneDriver.fromJsonObject)
            .toList()
      ];
    }

    // iterate over every bone driver
    if (boneDrivers != null) {
      for (var driver in boneDrivers) {
        // collect the frame data for the blendshapes that this driver uses
        var morphData = driver.transformations
            .map((String blendshape, Transformation transformation) {
          return MapEntry(
              blendshape, morphAnimationData.getData(blendshape).toList());
        });

        // apply the driver to the frame data
        var transformedQ = driver.transform(morphData).toList();

        // transform the quaternion to a Float32List
        var transformedF = _quaternionToFloatList(transformedQ);

        // add to the list of boneAnimations
        boneAnimations.add(BoneAnimationData(
            driver.bone, boneMeshes!, transformedF, frameLengthInMs));
      }
    }

    return DynamicAnimation(morphAnimationData, boneAnimations);
  }

  static Float32List _quaternionToFloatList(List<Quaternion> quats) {
    var data = Float32List(quats.length * 7);
    int i = 0;
    for (var quat in quats) {
      data.setRange(i, i + 7, [0, 0, 0, quat.w, quat.x, quat.y, quat.z]);
      i += 7;
    }
    return data;
  }

  DynamicAnimation(this.morphAnimation, this.boneAnimation);

  ///
  /// Load visemes fom a CSV file formatted according to the following header:
  /// "Timecode,BlendShapeCount,EyeBlinkLeft,EyeLookDownLeft,EyeLookInLeft,EyeLookOutLeft,EyeLookUpLeft,EyeSquintLeft,EyeWideLeft,EyeBlinkRight,EyeLookDownRight,EyeLookInRight,EyeLookOutRight,EyeLookUpRight,EyeSquintRight,EyeWideRight,JawForward,JawRight,JawLeft,JawOpen,MouthClose,MouthFunnel,MouthPucker,MouthRight,MouthLeft,MouthSmileLeft,MouthSmileRight,MouthFrownLeft,MouthFrownRight,MouthDimpleLeft,MouthDimpleRight,MouthStretchLeft,MouthStretchRight,MouthRollLower,MouthRollUpper,MouthShrugLower,MouthShrugUpper,MouthPressLeft,MouthPressRight,MouthLowerDownLeft,MouthLowerDownRight,MouthUpperUpLeft,MouthUpperUpRight,BrowDownLeft,BrowDownRight,BrowInnerUp,BrowOuterUpLeft,BrowOuterUpRight,CheekPuff,CheekSquintLeft,CheekSquintRight,NoseSneerLeft,NoseSneerRight,TongueOut,HeadYaw,HeadPitch,HeadRoll,LeftEyeYaw,LeftEyePitch,LeftEyeRoll,RightEyeYaw,RightEyePitch,RightEyeRoll"
  /// Returns two elements:
  /// - a list containing the names of each blendshape/morph key
  /// - a Float32List of length TxN, where T is the number of frames and N is the number of morph keys (i.e. the length of the list in the first element of the returned tuple).
  ///
  static Tuple2<List<String>, Float32List> _loadLiveLinkFaceCSV(String path) {
    final data = File(path)
        .readAsLinesSync()
        .where((l) => l.length > 1)
        .map((l) => l.split(","));

    final header = data.first;
    final numBlendShapes = header.length - 2;

    final _data = <double>[];

    for (var frame in data.skip(1)) {
      int numFrameWeights = frame.length - 2;
      // CSVs may contain rows where the "BlendShapeCount" column is set to "0" and/or the weight columns are simply missing.
      // This can happen when something went wrong while recording via an app (e.g. LiveLinkFace)
      // Whenever we encounter this type of row, we consider that all weights should be set to zero for that frame.
      if (numFrameWeights != int.parse(frame[1])) {
        _data.addAll(List<double>.filled(numBlendShapes, 0.0));
        continue;
      }

      //
      // Now, we check that the actual number of weight columns matches the header
      // we ignore the "BlendShapeCount" column (and just count the number of columns)
      // This is due to some legacy issues where we generated CSVs that had 61 weight columns, but accidentally left the "BlendShapeCount" column at 55
      // This is probably fine as we always have either zero weights (handled above), or all weights (handled below).
      // In other words, if this throws, we have a serious problem.
      if (numFrameWeights != numBlendShapes) {
        throw Exception(
            "Malformed CSV, header specifies ${numBlendShapes} columns but frame specified only $numFrameWeights weights");
      }

      _data.addAll(frame
          .skip(2)
          .map((weight) => double.parse(weight))
          .cast<double>()
          .toList());
    }
    return Tuple2(header.skip(2).toList(), Float32List.fromList(_data));
  }
}
