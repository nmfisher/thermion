import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/bone_driver.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';
import 'package:vector_math/vector_math.dart';

///
/// A class for loading animation data from a single CSV and allocating between morph/bone animation with help.
///
class DynamicAnimation {
  final MorphAnimationData morphAnimation;
  final List<BoneAnimationData> boneAnimation;

  factory DynamicAnimation.load(String meshName, String csvPath,
      {String? boneDriverConfigPath}) {
    // create a MorphAnimationData instance from the given CSV
    var llf = _loadLiveLinkFaceCSV(csvPath);
    var morphNames = llf
        .item1; //.where((name) => !boneDrivers.any((element) => element.blendshape == name));
    var morphAnimationData = MorphAnimationData(
      meshName,
      llf.item2,
      morphNames,
      1000 / 60.0,
    );

    final boneAnimations = <BoneAnimationData>[];

    // if applicable, load the bone driver config
    if (boneDriverConfigPath != null) {
      var boneData = json.decode(File(boneDriverConfigPath).readAsStringSync());
      // for each driver
      for (var key in boneData.keys()) {
        var driver = BoneDriver.fromJsonObject(boneData[key]);

        // get all frames for the single the blendshape
        var morphFrameData =
            morphAnimationData.getData(driver.blendshape).toList();

        // apply the driver to the blendshape weight
        var transformedQ = driver.transform(morphFrameData).toList();

        // transform the quaternion to a Float32List
        var transformedF = _quaternionToFloatList(transformedQ);

        // add to the list of boneAnimations
        boneAnimations.add(BoneAnimationData(
            driver.bone, meshName, transformedF, 1000.0 / 60.0));
      }
    }

    return DynamicAnimation(morphAnimationData, boneAnimations);
  }

  static Float32List _quaternionToFloatList(List<Quaternion> quats) {
    var data = Float32List(quats.length * 4);
    for (var quat in quats) {
      data.addAll([0, 0, 0, quat.w, quat.x, quat.y, quat.z]);
    }
    return data;
  }

  DynamicAnimation(this.morphAnimation, this.boneAnimation);

  ///
  /// Load visemes fom a CSV file formatted according to the following header:
  /// "Timecode,BlendShapeCount,EyeBlinkLeft,EyeLookDownLeft,EyeLookInLeft,EyeLookOutLeft,EyeLookUpLeft,EyeSquintLeft,EyeWideLeft,EyeBlinkRight,EyeLookDownRight,EyeLookInRight,EyeLookOutRight,EyeLookUpRight,EyeSquintRight,EyeWideRight,JawForward,JawRight,JawLeft,JawOpen,MouthClose,MouthFunnel,MouthPucker,MouthRight,MouthLeft,MouthSmileLeft,MouthSmileRight,MouthFrownLeft,MouthFrownRight,MouthDimpleLeft,MouthDimpleRight,MouthStretchLeft,MouthStretchRight,MouthRollLower,MouthRollUpper,MouthShrugLower,MouthShrugUpper,MouthPressLeft,MouthPressRight,MouthLowerDownLeft,MouthLowerDownRight,MouthUpperUpLeft,MouthUpperUpRight,BrowDownLeft,BrowDownRight,BrowInnerUp,BrowOuterUpLeft,BrowOuterUpRight,CheekPuff,CheekSquintLeft,CheekSquintRight,NoseSneerLeft,NoseSneerRight,TongueOut,HeadYaw,HeadPitch,HeadRoll,LeftEyeYaw,LeftEyePitch,LeftEyeRoll,RightEyeYaw,RightEyePitch,RightEyeRoll"
  /// Returns only those specified by [targetNames].
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
      if (numFrameWeights == int.parse(frame[1])) {
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
