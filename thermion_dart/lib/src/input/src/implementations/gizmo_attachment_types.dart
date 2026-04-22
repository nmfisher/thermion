import 'package:thermion_dart/thermion_dart.dart';

/// Represents what the gizmo is currently attached to - either a regular entity
/// or a specific bone within a skeletal mesh.
class AttachmentTarget {
  /// The entity this target represents. For bones, this is the bone entity.
  final ThermionEntity entity;

  /// The parent asset (only set if attached to a bone)
  final ThermionAsset? asset;

  /// The bone index (null if attached to entity directly)
  final int? boneIndex;

  /// The skin index (defaults to 0)
  final int skinIndex;

  const AttachmentTarget({
    required this.entity,
    this.asset,
    this.boneIndex,
    this.skinIndex = 0,
  });

  /// Whether this target is a bone (vs a regular entity)
  bool get isBone => boneIndex != null;

  /// Create a target for a regular entity
  factory AttachmentTarget.entity(ThermionEntity entity) {
    return AttachmentTarget(entity: entity);
  }

  /// Create a target for a bone
  factory AttachmentTarget.bone(
    ThermionAsset asset,
    int boneIndex, {
    int skinIndex = 0,
  }) {
    return AttachmentTarget(
      asset: asset,
      boneIndex: boneIndex,
      skinIndex: skinIndex,
      entity: 0, // Will be resolved when attaching
    );
  }

  @override
  String toString() {
    if (isBone) {
      return 'AttachmentTarget.bone(asset, boneIndex: $boneIndex, skinIndex: $skinIndex)';
    }
    return 'AttachmentTarget.entity($entity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentTarget &&
        other.entity == entity &&
        other.boneIndex == boneIndex &&
        other.skinIndex == skinIndex;
  }

  @override
  int get hashCode => Object.hash(entity, boneIndex, skinIndex);
}

/// Information about a bone in a skeletal mesh.
class BoneInfo {
  /// The name of the bone
  final String name;

  /// The bone index
  final int index;

  /// The bone entity
  final ThermionEntity entity;

  /// The skin index this bone belongs to
  final int skinIndex;

  const BoneInfo({
    required this.name,
    required this.index,
    required this.entity,
    this.skinIndex = 0,
  });

  @override
  String toString() =>
      'BoneInfo(name: $name, index: $index, skinIndex: $skinIndex)';
}
