import 'dart:math';

import 'package:thermion_dart/src/filament/src/interface/axis.dart';
import 'package:vector_math/vector_math_64.dart';

import 'bone_animation_data.dart';

enum ChannelType { Translation, Rotation }

class Channel {
  final Axis axis;
  final ChannelType type;

  Channel(this.axis, this.type);
}

enum RotationMode { ZYX, XYZ, XZY }

class BVHBone {
  final String name;

  final List<Channel> channels;

  RotationMode? rotationMode;

  BVHBone(this.name, this.channels) {
    for (int i = 0; i < channels.length; i++) {
      if (channels[i].type == ChannelType.Rotation) {
        if (channels[i].axis == Axis.X) {
          if (channels[i + 1].axis != Axis.Y) {
            throw Exception("TODO");
          }
          rotationMode = RotationMode.XYZ;
        } else if (channels[i].axis == Axis.Z) {
          if (channels[i + 1].axis != Axis.Y) {
            throw Exception("TODO");
          }
          rotationMode = RotationMode.ZYX;
        } else {
          throw Exception("TODO, YZX and YXZ not yet supported");
        }
        i += 2;
      }
    }
  }
}

class BVHParser {
  static Map<String, String> parseARPRemap(String arpRemapData) {
    final remap = <String, String>{};
    var data = arpRemapData.split("\n");
    for (int i = 0; i < data.length;) {
      var srcBone = data[i].split("%")[0];
      if (srcBone.isNotEmpty && srcBone != "None") {
        var targetBone = data[i + 1].trim();
        remap[targetBone] = srcBone;
      }
      i += 5;
    }
    return remap;
  }

  /// Biovision Hierarchical Data (BVH) is a simple plain-text format for representing skeletal/joint-based animations.
  /// The best reference I've found is this:
  ///   https://staffwww.dcs.shef.ac.uk/people/S.Maddock/publications/Motion%20Capture%20File%20Formats%20Explained.pdf
  /// To recap, the schema is as follows:
  /// HIERARCHY
  /// ROOT [bone_name] {
  ///   OFFSET [x] [y] [z]
  ///   CHANNELS [N] [Xposition] [Yposition] [Zposition] [Xrotation] [Yrotation] [Zrotation]
  ///   JOINT [child_bone_name] {
  ///     .. etc etc
  ///   }
  /// }
  /// MOTION
  /// Frames: [num_frames]
  /// Frame Time: [frame_time_in_ms]
  /// bone1_val1 bone1_val2 bone1_val3 bone1_val4 bone1_val5 bone1_val6 bone2_val1 ... boneN_valM
  ///
  /// The HIERARCHY section describes:
  /// - the structure of the skeleton (i.e. which bone is parented to which)
  /// - the translation offset of each bone from its parent
  /// - which channels will be animated for each bone
  /// The MOTION section contains the actual animation data. The first three lines are self-explanatory.
  /// Each line thereafter represents one frame, and thus the values for each bone/channel at that frame,
  /// in the same order as specified in the HIERARCHY section. Each transformation is relative to its parent.
  /// I assume that rotation-order is specified by the order of the channel specifiation (i.e. "Xrotation Yrotation Zrotation" means XYZ).
  /// Conventionally, the root node generally has 6 channels (3 translation coordinates + 3 rotation angles)
  /// BVH does not specify any coordinate system; note that Blender will export in its own system (i.e. +Z is up and +Y points into the screen).
  /// If you need a different coordinate system, pass in a transform via [changeOfBasis] matrix
  /// Currently only XYZ or ZYX are supported.
  /// Pass [frameLengthInMs] if you want to override the frame length specified in the BVH data.
  ///
  static BoneAnimationData parse(String data,
      {Map<String, String>? remap,
      RegExp? boneRegex,
      RotationMode rotationMode = RotationMode.ZYX,
      Vector3? rootTranslationOffset,
      Matrix3? basis,
      double? frameLengthInMs}) {
    basis ??= Matrix3.identity();
    // parse the list/hierarchy of bones
    final bones = <BVHBone>[];

    var iter = data.split("\n").iterator;

    int totalChannels = 0;

    String? boneName;

    final animation = <SkeletonTransform>[];
    while (iter.moveNext()) {
      final line = iter.current.trim();

      if (line.startsWith('ROOT') || line.startsWith('JOINT')) {
        boneName = line.split(' ')[1];
        if (remap?.containsKey(boneName) == true) {
          print("Remapping $boneName to ${remap![boneName]!}");
          boneName = remap![boneName]!;
        }
      } else if (line.startsWith("CHANNELS")) {
        var channelsString = line.split("CHANNELS")[1].trim().split(" ");
        var channels = channelsString.skip(1).map((channelName) {
          var channelType = channelName.contains("rotation")
              ? ChannelType.Rotation
              : ChannelType.Translation;

          var axis = Axis.values.firstWhere((a) {
            return a.name == channelName[0];
          });
          return Channel(axis, channelType);
        }).toList();
        var bone = BVHBone(boneName!, channels);
        bones.add(bone);
        boneName = null;
        totalChannels += channels.length;
      } else if (line.startsWith('Frame Time:')) {
        var frameTime = line.split(' ').last.trim();
        frameLengthInMs ??=
            double.parse(frameTime) * 1000; // Convert to milliseconds
        break;
      }
    }
    print("Using frame length $frameLengthInMs");

    final X = basis.transform(Vector3(1, 0, 0));
    final Y = basis.transform(Vector3(0, 1, 0));
    final Z = basis.transform(Vector3(0, 0, 1));

    while (iter.moveNext()) {
      final line = iter.current;
      if (line.isEmpty) {
        break;
      }

      final frameValues = <double>[];
      for (final entry in line.split(RegExp(r'\s+'))) {
        if (entry.isNotEmpty) {
          frameValues.add(double.parse(entry));
        }
      }
      if (frameValues.length != totalChannels) {
        throw Exception(
            "Length mismatch, got ${frameValues.length} frame values when ${totalChannels} channels specified");
      }
      late Vector3 rootTranslation = Vector3(
        frameValues[0],
        frameValues[1],
        frameValues[2],
      );

      rootTranslation = basis.transform(rootTranslation);

      if (rootTranslationOffset != null) {
        rootTranslation -= rootTranslationOffset;
      }

      SkeletonTransform frameData = [];
      int boneIndex = 0;
      int channelIndex = 0;
      var rotXYZ = <double>[0, 0, 0];
      var transXYZ = <double>[0, 0, 0];

      for (final value in frameValues) {
        var bone = bones[boneIndex];
        var channel = bone.channels[channelIndex];

        switch (channel.type) {
          case ChannelType.Translation:
            transXYZ[channel.axis.index] = value;
            break;
          case ChannelType.Rotation:
            rotXYZ[channel.axis.index] = value;
            break;
        }

        if (channelIndex == bone.channels.length - 1) {
          var trans = Vector3(transXYZ[0], transXYZ[1], transXYZ[2]);
          var x = Quaternion.axisAngle(X, radians(rotXYZ[0]));
          var y = Quaternion.axisAngle(Y, radians(rotXYZ[1]));
          var z = Quaternion.axisAngle(Z, radians(rotXYZ[2]));
          late Quaternion rot;
          switch (rotationMode) {
            case RotationMode.XYZ:
              rot = ((x * y) * z).normalized();
              break;
            case RotationMode.ZYX:
              rot = ((z * y) * x).normalized();
              break;
            case RotationMode.XZY:
              rot = ((x * z) * y).normalized();
              break;
          }
          if (boneRegex?.hasMatch(bone.name) != false) {
            frameData.add((rotation: rot, translation: trans));
          }

          channelIndex = 0;
          rotXYZ = <double>[0, 0, 0];
          transXYZ = <double>[0, 0, 0];
          boneIndex++;
        } else {
          channelIndex++;
        }
      }
      animation.add(frameData);
    }

    // filter the list of bone names so we're only specifying those that match the regexp
    late List<String> filteredBones;
    if (boneRegex == null) {
      filteredBones = bones.map((b) => b.name).toList();
    } else {
      filteredBones = bones
          .where((b) => boneRegex!.hasMatch(b.name))
          .map((b) => b.name)
          .toList();
    }
    return BoneAnimationData(filteredBones, animation,
        frameLengthInMs: frameLengthInMs!, space: Space.ParentWorldRotation);
  }

  static double radians(double degrees) => degrees * (pi / 180.0);
}
