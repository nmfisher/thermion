import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Manager for transform components in Filament.
///
/// TransformManager is used to add transform components to entities, giving them
/// position and orientation in space. Transforms are organized in hierarchies
/// where each transform is relative to its parent transform.
///
/// This is the primary interface for:
/// - Creating and managing transform components
/// - Setting local and world transforms
/// - Managing parent-child relationships
/// - Transform hierarchy operations
/// - Scaling to unit cube
abstract class TransformManager<T> extends NativeHandle<T> {
  // ============================================================================
  // Component queries
  // ============================================================================

  /// Returns true if the entity has a transform component.
  bool hasComponent(ThermionEntity entity);

  /// Returns true if this manager has no transform components.
  bool empty();

  /// Returns the total number of transform components managed by this manager.
  int getComponentCount();

  // ============================================================================
  // Component lifecycle
  // ============================================================================

  /// Creates a transform component for the specified entity.
  ///
  /// If the entity already has a transform component, this is a no-op.
  ///
  /// [entity] The entity to create a transform component for
  Future createComponent(ThermionEntity entity);

  /// Removes the transform component from the specified entity.
  ///
  /// If the entity does not have a transform component, this is a no-op.
  ///
  /// [entity] The entity to remove the transform component from
  Future removeComponent(ThermionEntity entity);

  // ============================================================================
  // Transform operations
  // ============================================================================

  /// Gets the local transform matrix of the entity (relative to parent).
  ///
  /// [entity] The entity containing the transform component
  /// Returns the local transform as a Matrix4
  Matrix4 getLocalTransform(ThermionEntity entity);

  /// Gets the world transform matrix of the entity (relative to world root).
  ///
  /// [entity] The entity containing the transform component
  /// Returns the world transform as a Matrix4
  Matrix4 getWorldTransform(ThermionEntity entity);

  /// Sets the local transform matrix of the entity.
  ///
  /// [entity] The entity containing the transform component
  /// [transform] The local transform matrix (relative to parent)
  void setTransform(ThermionEntity entity, Matrix4 transform);

  /// Sets the local transform matrix on the render thread.
  ///
  /// Use this when setting transforms from outside the render pass
  /// (e.g. bone posing from a gizmo callback) to avoid race conditions.
  ///
  /// [entity] The entity containing the transform component
  /// [transform] The local transform matrix (relative to parent)
  Future setTransformAsync(ThermionEntity entity, Matrix4 transform);

  /// Scales the entity to fit within a unit cube while preserving aspect ratio.
  ///
  /// This is useful for normalizing assets to a consistent size.
  ///
  /// [entity] The entity containing the transform component
  /// [boundingBox] The bounding box to scale from
  /// Returns true if successful, false if the entity has no transform component
  bool transformToUnitCube(ThermionEntity entity, Aabb3 boundingBox);

  // ============================================================================
  // Hierarchy management
  // ============================================================================

  /// Sets the parent entity for the specified child entity.
  ///
  /// [child] The child entity
  /// [parent] The parent entity (use null to remove parent)
  /// [preserveScaling] Whether to preserve the child's world scale when reparenting
  void setParent(ThermionEntity child, ThermionEntity? parent, {bool preserveScaling = false});

  /// Gets the parent entity of the specified child entity.
  ///
  /// [child] The child entity
  /// Returns the parent entity, or null if the child has no parent (is a root)
  ThermionEntity? getParent(ThermionEntity child);

  /// Gets the root ancestor of the specified entity.
  ///
  /// Traverses up the hierarchy to find the top-most parent.
  ///
  /// [entity] The entity to find the ancestor for
  /// Returns the root ancestor entity, or null if the entity has no transform component
  ThermionEntity? getAncestor(ThermionEntity entity);

  // ============================================================================
  // Transform transactions
  // ============================================================================

  /// Opens a local transform transaction for bulk updates.
  ///
  /// During a transaction, getWorldTransform() may return invalid values
  /// until commitLocalTransformTransaction() is called. However, setTransform()
  /// will perform significantly better and in constant time.
  ///
  /// This is useful when updating many transforms and the transform hierarchy is deep.
  /// The system never closes the transaction automatically, so commitLocalTransformTransaction()
  /// must be called when done.
  void openLocalTransformTransaction();

  /// Commits the currently open local transform transaction.
  ///
  /// When this returns, calls to getWorldTransform() will return proper values.
  ///
  /// Failing to call this method when done updating local transforms will cause
  /// rendering problems. The system never closes the transaction automatically.
  void commitLocalTransformTransaction();

  // ============================================================================
  // Children management
  // ============================================================================

  /// Gets the number of children for the specified parent entity.
  ///
  /// [parent] The parent entity to query for children
  /// Returns the number of direct children, or 0 if the entity has no children or no transform component
  int getChildCount(ThermionEntity parent);

  /// Gets a list of all direct children for the specified parent entity.
  ///
  /// [parent] The parent entity to query for children
  /// Returns a list of child entity IDs, or an empty list if no children exist
  List<ThermionEntity> getChildren(ThermionEntity parent);
}