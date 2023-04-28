import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

///
/// Model class for bone animation frame data.
/// To create dynamic/runtime bone animations (as distinct from animations embedded in a glTF asset), create an instance containing the relevant
/// data and pass to the [setBoneAnimation] method on a [FilamentController].
/// [frameData] is laid out as [locX, locY, locZ, rotW, rotX, rotY, rotZ]
///
class BoneAnimationData {
  final String boneName;
  final List<String> meshNames;
  final Float32List frameData;
  double frameLengthInMs;
  BoneAnimationData(
      this.boneName, this.meshNames, this.frameData, this.frameLengthInMs);
}
