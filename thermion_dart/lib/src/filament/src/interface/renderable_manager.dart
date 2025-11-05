import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Manager for renderable components in Filament.
///
/// RenderableManager is responsible for managing renderable entities - entities that
/// can be drawn. Renderables consist of primitives, each with their own geometry and
/// material. All primitives in a renderable share rendering attributes like shadow
/// casting, frustum culling, and layer visibility.
///
/// This is the primary interface for:
/// - Managing material instances on primitives
/// - Controlling visibility and culling behavior
/// - Configuring shadows and lighting
/// - Setting rendering priority and blend order
/// - Managing morph targets and skinning
/// - Manipulating bounding boxes
abstract class RenderableManager<T> extends NativeHandle<T> {
  // ============================================================================
  // Component queries
  // ============================================================================

  /// Returns true if the entity has a renderable component.
  bool hasComponent(ThermionEntity entity);

  /// Returns true if this manager has no components.
  bool empty();

  /// Returns true if the entity is renderable (has a valid renderable instance).
  bool isRenderable(ThermionEntity entity);

  /// Returns the total number of renderable components managed by this manager.
  int getComponentCount();

  // ============================================================================
  // Material instance management
  // ============================================================================

  /// Sets the material instance for the specified primitive.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] The index of the primitive (0-based)
  /// [materialInstance] The material instance to bind
  Future<bool> setMaterialInstanceAt(
      ThermionEntity entity, int primitiveIndex, MaterialInstance materialInstance);

  /// Gets the material instance bound to the specified primitive.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] The index of the primitive (0-based)
  /// Returns the material instance, or null if none is bound
  Future<MaterialInstance?> getMaterialInstanceAt(
      ThermionEntity entity, int primitiveIndex);

  /// Clears the material instance for the specified primitive.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] The index of the primitive (0-based)
  Future clearMaterialInstanceAt(ThermionEntity entity, int primitiveIndex);

  // ============================================================================
  // Primitive management
  // ============================================================================

  /// Returns the number of primitives in the renderable.
  int getPrimitiveCount(ThermionEntity entity);

  // ============================================================================
  // Bounding box management
  // ============================================================================

  /// Gets the axis-aligned bounding box used for frustum culling.
  ///
  /// Returns an Aabb3 representing the bounding box in object space.
  Aabb3 getAxisAlignedBoundingBox(ThermionEntity entity);

  /// Sets the axis-aligned bounding box used for frustum culling.
  ///
  /// The bounding box should encompass all possible vertex positions,
  /// including those from skinning and morphing.
  ///
  /// [entity] The entity containing the renderable
  /// [aabb] The new bounding box in object space
  Future setAxisAlignedBoundingBox(ThermionEntity entity, Aabb3 aabb);

  /// Alias for getAxisAlignedBoundingBox.
  Aabb3 getBoundingBox(ThermionEntity entity);

  // ============================================================================
  // Layer mask and visibility
  // ============================================================================

  /// Sets bits in the visibility layer mask.
  ///
  /// This provides a simple mechanism for hiding/showing groups of renderables.
  /// See View.setVisibleLayers() for controlling which layers are rendered.
  ///
  /// [entity] The entity containing the renderable
  /// [select] The set of bits to affect
  /// [values] The replacement values for the affected bits
  ///
  /// Example: To set bit 1 and reset bits 0 and 2 while leaving others unaffected:
  /// setLayerMask(entity, 7, 2)
  Future setLayerMask(ThermionEntity entity, int select, int values);

  /// Gets the current layer mask value.
  int getLayerMask(ThermionEntity entity);

  /// Sets which visibility layer this renderable belongs to.
  ///
  /// This is a convenience method that sets a single layer bit.
  /// [layer] The layer index (0-7)
  Future setVisibilityLayer(ThermionEntity entity, int layer);

  // ============================================================================
  // Priority and channel
  // ============================================================================

  /// Sets the rendering priority (0-7, where 7 is lowest priority/rendered last).
  ///
  /// Priority provides coarse-grained control over draw order. Priority is applied
  /// separately for opaque and translucent objects - opaque objects are always
  /// drawn before translucent ones regardless of priority.
  ///
  /// [entity] The entity containing the renderable
  /// [priority] Priority value, clamped to 0-7
  Future setPriority(ThermionEntity entity, int priority);

  /// Sets the rendering channel (0-3).
  ///
  /// Channels enforce the strongest ordering - all renderables in a channel are
  /// rendered together before the next channel, regardless of other settings.
  ///
  /// Channels 0 and 1 may not use materials with screenspace refraction.
  ///
  /// [entity] The entity containing the renderable
  /// [channel] Channel value, clamped to 0-3
  Future setChannel(ThermionEntity entity, int channel);

  // ============================================================================
  // Culling and fog
  // ============================================================================

  /// Controls frustum culling (enabled by default).
  ///
  /// Note: This is frustum culling, not backface culling (which is controlled
  /// via the material).
  Future setCulling(ThermionEntity entity, bool enabled);

  /// Controls whether this renderable is affected by large-scale fog.
  ///
  /// [entity] The entity containing the renderable
  /// [enabled] True to enable fog, false to disable (default is true)
  Future setFogEnabled(ThermionEntity entity, bool enabled);

  /// Returns whether fog is enabled for this renderable.
  bool getFogEnabled(ThermionEntity entity);

  // ============================================================================
  // Light channels
  // ============================================================================

  /// Enables or disables a light channel (0-7).
  ///
  /// Light channels allow selective lighting - a renderable is only lit by
  /// lights that share at least one enabled channel. Channel 0 is enabled
  /// by default.
  ///
  /// [entity] The entity containing the renderable
  /// [channel] Light channel index (0-7)
  /// [enable] True to enable, false to disable
  Future setLightChannel(ThermionEntity entity, int channel, bool enable);

  /// Returns whether a light channel is enabled.
  bool getLightChannel(ThermionEntity entity, int channel);

  // ============================================================================
  // Shadow options
  // ============================================================================

  /// Controls whether this renderable casts shadows.
  ///
  /// For VSM shadows, castShadows should only be disabled if either:
  /// - receiveShadows is also disabled, or
  /// - The object is guaranteed not to cast shadows on itself or other objects
  ///
  /// [entity] The entity containing the renderable
  /// [enabled] True to cast shadows, false otherwise
  Future setCastShadows(ThermionEntity entity, bool enabled);

  /// Returns whether this renderable casts shadows.
  bool isShadowCaster(ThermionEntity entity);

  /// Controls whether this renderable receives shadows.
  ///
  /// [entity] The entity containing the renderable
  /// [enabled] True to receive shadows, false otherwise
  Future setReceiveShadows(ThermionEntity entity, bool enabled);

  /// Returns whether this renderable receives shadows.
  bool isShadowReceiver(ThermionEntity entity);

  /// Controls whether this renderable uses screen-space contact shadows.
  ///
  /// This is more expensive but can improve shadow quality, especially in
  /// large scenes.
  ///
  /// [entity] The entity containing the renderable
  /// [enabled] True to enable screen-space contact shadows
  Future setScreenSpaceContactShadows(ThermionEntity entity, bool enabled);

  // ============================================================================
  // Blend order
  // ============================================================================

  /// Sets the drawing order for blended primitives.
  ///
  /// The blend order can be global or local to the renderable. In either case,
  /// the renderable's priority takes precedence.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] The primitive index
  /// [order] Draw order number (only lowest 15 bits are used)
  Future setBlendOrderAt(ThermionEntity entity, int primitiveIndex, int order);

  /// Sets whether blend order is global or local to this renderable.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] The primitive index
  /// [enabled] True for global blend ordering, false for local (default)
  Future setGlobalBlendOrderEnabledAt(
      ThermionEntity entity, int primitiveIndex, bool enabled);

  // ============================================================================
  // Morph targets
  // ============================================================================

  /// Updates vertex morphing weights.
  ///
  /// The renderable must have been built with morphing enabled.
  /// For legacy morphing, only the first 4 weights are used.
  ///
  /// [entity] The entity containing the renderable
  /// [weights] Array of morph target weights
  /// [count] Number of weights to set
  /// [offset] Index of the first weight to set (default 0)
  Future setMorphWeights(
      ThermionEntity entity, List<double> weights, int count, {int offset = 0});

  /// Returns the number of morph targets.
  int getMorphTargetCount(ThermionEntity entity);
}
