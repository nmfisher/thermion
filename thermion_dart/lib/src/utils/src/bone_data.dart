import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

/// Represents a bone transform for vertex skinning.
///
/// This matches Filament's RenderableManager::Bone struct which consists of
/// a unit quaternion (rotation) and a translation vector.
///
/// The Bone struct is laid out as 8 floats:
/// - 4 floats for the quaternion (x, y, z, w)
/// - 3 floats for the translation (x, y, z)
/// - 1 float reserved (padding)
class BoneData {
  /// Rotation as a unit quaternion.
  final Quaternion rotation;

  /// Translation vector.
  final Vector3 translation;

  const BoneData({required this.rotation, required this.translation});

  /// Creates a bone with an identity transform (no rotation, no translation).
  factory BoneData.identity() {
    return BoneData(rotation: Quaternion.identity(), translation: Vector3.zero());
  }

  /// Converts a list of BoneData to a Float32List for FFI.
  ///
  /// Each bone is represented as 8 floats in the following order:
  /// - quaternion.x, quaternion.y, quaternion.z, quaternion.w
  /// - translation.x, translation.y, translation.z, reserved (0.0)
  static Float32List toFloat32List(List<BoneData> bones) {
    final result = Float32List(bones.length * 8);
    for (int i = 0; i < bones.length; i++) {
      final bone = bones[i];
      final offset = i * 8;
      result[offset + 0] = bone.rotation.x;
      result[offset + 1] = bone.rotation.y;
      result[offset + 2] = bone.rotation.z;
      result[offset + 3] = bone.rotation.w;
      result[offset + 4] = bone.translation.x;
      result[offset + 5] = bone.translation.y;
      result[offset + 6] = bone.translation.z;
      result[offset + 7] = 0.0; // reserved
    }
    return result;
  }

  /// Converts a list of Matrix4 transforms to a Float32List for FFI.
  ///
  /// Each matrix is represented as 16 floats in column-major order.
  static Float32List matricesToFloat32List(List<Matrix4> matrices) {
    final result = Float32List(matrices.length * 16);
    for (int i = 0; i < matrices.length; i++) {
      final offset = i * 16;
      final storage = matrices[i].storage;
      for (int j = 0; j < 16; j++) {
        result[offset + j] = storage[j].toDouble();
      }
    }
    return result;
  }

  /// Creates a BoneData from a Matrix4 transform.
  ///
  /// Extracts the rotation (as a quaternion) and translation from the matrix.
  factory BoneData.fromMatrix4(Matrix4 matrix) {
    final rotation = Quaternion.fromRotation(matrix.getRotation());
    final translation = matrix.getTranslation();
    return BoneData(rotation: rotation, translation: translation);
  }

  /// Creates a list of BoneData from a list of Matrix4 transforms.
  static List<BoneData> fromMatrix4List(List<Matrix4> matrices) {
    return matrices.map((m) => BoneData.fromMatrix4(m)).toList();
  }
}
