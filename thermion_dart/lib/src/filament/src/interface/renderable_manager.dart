import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Manager for renderable components in Filament.
///
/// RenderableManager is responsible for managing renderable entities - entities
/// that can be drawn. Renderables consist of primitives, each with their own
/// geometry and material. All primitives in a renderable share rendering
/// attributes like shadow casting, frustum culling, and layer visibility.
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
  Future<bool> setMaterialInstanceAt(ThermionEntity entity, int primitiveIndex, MaterialInstance materialInstance);

  /// Replaces the geometry of a primitive at runtime without an index buffer
  /// (Filament's attribute-less/procedural rendering path).
  ///
  /// [vertices] must be a vertex buffer built with `bufferCount(0)` and no
  /// declared attributes; vertex positions are computed from
  /// `getVertexIndex()` in the material's vertex block.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] Zero-based index of the primitive
  /// [type] Topology of the primitive (e.g., PrimitiveType.TRIANGLES)
  /// [vertices] Attribute-less vertex buffer
  /// [offset] Where to start reading in the vertex buffer (in vertices)
  /// [count] Number of vertices to read
  Future<bool> setGeometryAtNonIndexed(
    ThermionEntity entity,
    int primitiveIndex,
    PrimitiveType type,
    VertexBuffer vertices,
    int offset,
    int count,
  );

  /// Gets the material instance bound to the specified primitive.
  ///
  /// [entity] The entity containing the renderable
  /// [primitiveIndex] The index of the primitive (0-based)
  /// Returns the material instance, or null if none is bound
  Future<MaterialInstance?> getMaterialInstanceAt(ThermionEntity entity, int primitiveIndex);

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
  Future setGlobalBlendOrderEnabledAt(ThermionEntity entity, int primitiveIndex, bool enabled);

  /// Replaces all vertex morphing weights.
  ///
  /// The renderable must have been built with morphing enabled.
  /// For legacy morphing, only the first 4 weights are used.
  ///
  /// [entity] The entity containing the renderable
  /// [weights] One value per morph target, in target-index order
  Future<void> setMorphWeights(ThermionEntity entity, List<double> weights);

  /// Updates one vertex morphing weight without changing the other targets.
  Future<void> setMorphWeightAt(ThermionEntity entity, int targetIndex, double weight);

  /// Returns the number of morph targets.
  int getMorphTargetCount(ThermionEntity entity);

  // ============================================================================
  // Skinning
  // ============================================================================

  /// Updates the bone transforms for a skinned renderable.
  ///
  /// The renderable must have been built with skinning enabled (via the
  /// builder's `skinning()` method, or implicitly when loading a skinned
  /// glTF asset). Transforms are applied in the range
  /// `[offset, offset + transforms.length)`.
  ///
  /// [entity] The entity containing the skinned renderable
  /// [transforms] A list of 4x4 bone transforms (column-major)
  /// [offset] Index of the first bone to update (default 0)
  Future setBonesFromMat4(ThermionEntity entity, List<Matrix4> transforms, {int offset = 0});

  /// Sets bone transforms for a skinned renderable using BoneData.
  ///
  /// The renderable must have been built with skinning enabled.
  /// BoneData uses quaternion+translation format which is more memory efficient.
  ///
  /// [entity] The entity containing the renderable
  /// [bones] List of bone transforms
  /// [offset] Index of the first bone to set (default 0)
  Future setBonesFromBone(ThermionEntity entity, List<BoneData> bones, {int offset = 0});

  /// Creates a builder for constructing renderables.
  ///
  /// [primitiveCount] The number of primitives that will be supplied to the
  /// builder
  RenderableBuilder createBuilder(int primitiveCount);

  /// Creates a builder for constructing vertex buffers.
  VertexBufferBuilder createVertexBufferBuilder();

  BufferObjectBuilder createBufferObjectBuilder();

  /// Creates a builder for constructing index buffers.
  IndexBufferBuilder createIndexBufferBuilder();
}

/// Builder for creating renderable components.
///
/// Renderables are bundles of primitives, each with its own geometry and material.
/// All primitives in a renderable share rendering attributes like shadows and culling.
///
/// Usage:
/// ```dart
/// final builder = renderableManager.createBuilder(1);
/// builder
///   ..boundingBox(aabb)
///   ..material(0, materialInstance)
///   ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, vertexCount)
///   ..castShadows(true)
///   ..receiveShadows(true);
/// await builder.build(entity);
/// ```
abstract class RenderableBuilder {
  /// Sets the axis-aligned bounding box for frustum culling.
  ///
  /// This should encompass all possible vertex positions. Mandatory unless culling is disabled.
  void boundingBox(Aabb3 aabb);

  /// Binds a material instance to the specified primitive.
  ///
  /// [primitiveIndex] Zero-based index of the primitive
  /// [materialInstance] The material instance to bind
  void material(int primitiveIndex, MaterialInstance materialInstance);

  /// Specifies the geometry data for a primitive.
  ///
  /// [primitiveIndex] Zero-based index of the primitive
  /// [type] Topology of the primitive (e.g., PrimitiveType.triangles)
  /// [vertices] Vertex buffer containing attribute data
  /// [indices] Index buffer (u16 or u32)
  /// [offset] Where to start reading in the index buffer (in indices)
  /// [count] Number of indices to read
  void geometry(
    int primitiveIndex,
    PrimitiveType type,
    VertexBuffer vertices,
    IndexBuffer indices,
    int offset,
    int count,
  );

  /// Specifies non-indexed geometry data for a primitive (Filament's
  /// attribute-less/procedural rendering path).
  ///
  /// The vertex buffer must have been built with `bufferCount(0)` and no
  /// declared attributes, and the material must compute its positions from
  /// `getVertexIndex()` in the vertex block (see Filament's "Procedural and
  /// attribute-less rendering" documentation). Skinning and morphing are not
  /// supported on attribute-less primitives.
  ///
  /// [primitiveIndex] Zero-based index of the primitive
  /// [type] Topology of the primitive (e.g., PrimitiveType.TRIANGLES)
  /// [vertices] Attribute-less vertex buffer (bufferCount(0))
  /// [offset] Where to start reading in the vertex buffer (in vertices)
  /// [count] Number of vertices to read
  void geometryNonIndexed(int primitiveIndex, PrimitiveType type, VertexBuffer vertices, int offset, int count);

  /// Sets the rendering priority (0-7, where 7 is lowest/rendered last).
  ///
  /// Priority provides coarse-grained draw order control. Applied separately
  /// for opaque and translucent objects.
  void priority(int priority);

  /// Sets the rendering channel (0-3).
  ///
  /// Channels enforce the strongest ordering. All renderables in a channel
  /// are rendered together before the next channel.
  void channel(int channel);

  /// Controls frustum culling (enabled by default).
  void culling(bool enabled);

  /// Controls whether this renderable casts shadows.
  void castShadows(bool enabled);

  /// Controls whether this renderable receives shadows.
  void receiveShadows(bool enabled);

  /// Controls whether this renderable is affected by large-scale fog.
  void fog(bool enabled);

  /// Enables or disables a light channel (0-7).
  ///
  /// Light channel 0 is enabled by default.
  void lightChannel(int channel, bool enabled);

  /// Sets bits in the visibility layer mask.
  ///
  /// [select] The set of bits to affect
  /// [values] The replacement values for the affected bits
  void layerMask(int select, int values);

  /// Controls screen-space contact shadows (more expensive but better quality).
  void screenSpaceContactShadows(bool enabled);

  /// Sets the drawing order for blended primitives.
  ///
  /// [primitiveIndex] The primitive index
  /// [order] Draw order number (only lowest 15 bits used)
  void blendOrder(int primitiveIndex, int order);

  /// Sets whether blend order is global or local to this renderable.
  ///
  /// [primitiveIndex] The primitive index
  /// [enabled] True for global, false for local (default)
  void globalBlendOrderEnabled(int primitiveIndex, bool enabled);

  /// Specifies the number of draw instances of this renderable.
  ///
  /// The default is 1 instance and the maximum number of instances allowed
  /// is 32767. 0 is invalid.
  ///
  /// All instances are culled using the same bounding box, so care must be
  /// taken to make sure all instances render inside the specified bounding box.
  ///
  /// The material must set its `instanced` parameter to `true` in order to use
  /// getInstanceIndex() in the vertex or fragment shader to get the instance
  /// index and possibly adjust the position or transform.
  ///
  /// [instanceCount] The number of instances, silently clamped between 1 and 32767.
  void instances(int instanceCount);

  // ============================================================================
  // Skinning
  // ============================================================================

  /// Configures skinning with 4x4 transformation matrices.
  ///
  /// [boneCount] Number of bones
  /// [transforms] Initial bone transforms as 4x4 matrices in column-major order
  void skinning(int boneCount, List<Matrix4> transforms);

  /// Configures skinning with BoneData (quaternion + translation).
  ///
  /// [boneCount] Number of bones
  /// [bones] Initial bone transforms
  void skinningFromBone(int boneCount, List<BoneData> bones);

  // Enables skinning buffer mode for sharing bone data between renderables.
  //
  // When enabled, use setSkinningBuffer on the renderable instead of
  // setBonesFromMat4. [enabled] Whether to enable skinning buffer mode
  void enableSkinningBuffers(bool enabled);

  // Sets bone indices and weights for a primitive. Each bone-weight pair is a
  // Float32List with 2 elements: [boneIndex, weight]. The data must be
  // rectangular with the same number of pairs for all vertices.
  //
  // [primitiveIndex] The primitive index [indicesAndWeights] Bone index and
  // weight pairs for all vertices [bonesPerVertex] Number of bones influencing
  // each vertex
  void boneIndicesAndWeights(int primitiveIndex, List<Float32List> indicesAndWeights, int bonesPerVertex);

  /// Builds the renderable and attaches it to the entity.
  ///
  /// [entity] The entity to attach the renderable component to
  /// Returns true on success, false on error
  ///
  /// The builder is consumed after this call and cannot be reused.
  Future<bool> build(ThermionEntity entity);
}
