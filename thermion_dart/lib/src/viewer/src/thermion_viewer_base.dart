import 'package:thermion_dart/thermion_dart.dart';
import '../../filament/src/interface/defaults.dart';
import 'dart:async';

// A high-level interface for managing scene:
// - adding/removing assets, lights and cameras
// - setting post-processing options
// -
// Broadly, an instance of [ThermionViewer] encapsulates a single Filament
// Scene, Camera and a View, with some additional commonly-used entities
// (skybox, background image, etc).
//
// If you know what you are doing, you can use a lower level interface by
// using the methods directly via FilamentApp.instance
//
// Note that this is a Dart class, not a Flutter class.
abstract class ThermionViewer {
  // The Filament [View] encapsulated by this viewer. Call View.getScene to get
  // the Filament [Scene].
  View get view;

  // The [FilamentApp] (engine, render thread, managers) that owns this viewer.
  // Helpers (gizmos, overlays, input delegates) should use this instead of the
  // [FilamentApp.instance] global so they bind to the correct engine when more
  // than one viewer/app coexists.
  FilamentApp get app;

  // If [true], this viewer will render itself on every frame.
  Future setRendering(bool render);

  // Whether this viewer should automatically rendering on every frame.
  bool get rendering;

  // Renders a single frame (bypassing animations and plugins).
  Future renderSingleFrame();

  /// Sets the shared render-loop framerate cap.
  ///
  /// Framerate is engine-wide rather than viewer-specific. New code should
  /// call [FilamentApp.setTargetFramerate] directly.
  @Deprecated('Use FilamentApp.instance!.setTargetFramerate(framerate)')
  Future<void> setFrameRate(int framerate);

  // Destroys/disposes the viewer (including the entire scene). You cannot use the viewer after calling this method.
  Future dispose();

  // Return the textured quad used for the background image.
  Future<TexturedQuad> getBackgroundImage();

  // Set the background image to [path] (which should be .png, .jpg, or .ktx
  // file). This will be rendered at the maximum depth (i.e. behind all other
  // objects including the skybox). If [fillHeight] is false, the image will be
  // rendered at its original size. Note this may cause issues with pixel
  // density so be sure to specify the correct resolution If [fillHeight] is
  // true, the image will be stretched/compressed to fit the height of the
  // viewport.
  Future setBackgroundImage(String path, {bool fillHeight = false});

  // Set the background image from [texture].
  Future setBackgroundImageFromTexture(Texture texture);

  // Moves the background image to the relative offset from the origin (bottom-left) specified by [x] and [y].
  // If [clamp] is true, the image cannot be positioned outside the bounds of the viewport.
  //
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false});

  // Removes the background image.
  Future clearBackgroundImage({bool destroy = false});

  // Returns the skybox currently attached to this viewer's scene, or null.
  // The viewer does not cache the skybox; this always reflects the scene, so
  // it also returns skyboxes attached directly via [Scene.setSkybox].
  Future<Skybox?> getSkybox();

  /// Creates a solid-color [Skybox], attaches it to this viewer's scene, and
  /// returns it.
  ///
  /// The viewer does not cache the returned skybox. It remains attached to the
  /// scene until it is replaced or detached with [removeSkybox].
  Future<Skybox> setBackgroundColor(double r, double g, double b, double alpha);

  // Load a skybox from [skyboxPath] (which must be a .ktx file). Returns the
  // created [Skybox], which may be mutated (e.g. [Skybox.setColor],
  // [Skybox.setLayerMask]) or detached via [removeSkybox].
  Future<Skybox> loadSkybox(String skyboxPath);

  /// Detaches and returns the skybox currently attached to the scene.
  ///
  /// This does not destroy the returned [Skybox]. The caller is responsible
  /// for destroying it and, for a texture-backed skybox, its [Skybox.getTexture]
  /// after the skybox is no longer needed.
  Future<Skybox?> removeSkybox();

  // Creates an indirect light by loading the reflections/irradiance from the
  // KTX file. Only one indirect light can be active at any given time; if an
  // indirect light has already been loaded, it will be replaced.
  Future loadIbl(String lightingPath, {double intensity = 30000, bool destroyExisting = true});

  //
  Future loadIblFromTexture(
    Texture texture, {
    Texture? reflectionsTexture,
    double intensity = 30000,
    bool destroyExisting = true,
  });

  //
  // Rotates the IBL & skybox.
  //
  Future rotateIbl(Matrix3 rotation);

  //
  // Removes the image-based light from the scene.
  // If [destroy] is true, the indirect light and all associated resources
  // (irradiance/reflection textures) will be destroyed.
  //
  Future removeIbl({bool destroy = true});

  // Adds a direct light to the scene.
  // See LightManager.h for details
  // Note that [sunAngularRadius] is in degrees,
  // whereas [spotLightConeInner] and [spotLightConeOuter] are in radians
  //
  Future<ThermionEntity> addDirectLight(DirectLight light);

  // Remove a light from the scene.
  Future removeLight(ThermionEntity light);

  // Remove all direct lights from the scene.
  Future destroyLights();

  // Load the glTF asset from [uri] (which must point to a file with the
  // extension `.glb` or `.gltf`. `file://` URIs are always supported;
  // `asset://` URIs are only supported if running in a Flutter application.
  //
  // [resourceUri] is ignored for `.glb.` files; if provided, all asset paths
  // in the `.gltf` file will be resolved relative to this path. If
  // [resourceUri] is not provided, all asset paths in `.gltf` files will be
  // resolved relative to the URI of the file itself (so if
  // [uri] is asset://assets/scene.gltf, the loader will attempt to load
  // asset://assets/scene.bin, asset://assets/texture.png, and so on).
  //
  // If [addToScene] is [true], all renderable entities (including lights)
  // in the asset will be added to the scene.
  //
  // [initialInstances] must be >= 1, and determines the number of instances
  // that are pre-allocated when the asset is created. See [AssetLoader.h]
  // for a detailed explanation of glTF instances.

  // The [ThermionAsset] returned by [loadGltf] will always have at least one
  // instance. If only one instance is created, then the parent [ThermionAsset]
  // and the "instance" [ThermionAsset] can be used interchangeably.
  //
  // If [releaseSourceData] is false, you can create additional instances by
  // calling [createInstance] on the returned asset. Instances can be retrieved
  // with [getInstances].
  //
  // If [releaseSourceData] is true, [initialInstances] will be created but no
  // further instances will be able to be created.
  //
  // If [releaseSourceData] is false and you only need a fixed set of
  // instances, call [ThermionAsset.releaseSourceData] once those instances
  // have been created to free the CPU-side glTF source copy (the original
  // .glb buffer). Afterwards, [createInstance] will no longer be available.
  //
  // Creating instances by specifying [initialInstances] at asset load time is
  // generally more efficient than dynamically instantating at a later time.
  //
  // If [rebuildVertices] is true, vertex buffers are rebuilt after loading
  // with a superset of attributes (POSITION, TANGENTS, UV0, CUSTOM0, and
  // optionally BONE_INDICES/BONE_WEIGHTS). Vertices are unwelded so each
  // triangle has unique vertices with barycentric coordinates in CUSTOM0.
  // This allows freely swapping materials (e.g. wireframe, solid shading)
  // via [setMaterialInstanceForAll] without creating separate overlay entities.
  // Increases vertex memory usage (~3x vertex count) but preserves the full
  // glTF feature set (animations, skeleton, instancing).
  //
  // If [editableVertices] is true, vertex buffers are rebuilt without
  // unwelding: source vertex order and triangle indices are preserved. This
  // exposes mutable buffers while retaining compatibility with glTF morph
  // targets. It is mutually exclusive with [rebuildVertices].
  //
  // If [loadResourcesAsync] is true, resources (textures, materials, etc) will
  // be loaded asynchronously. Some material/texture pop-in is expected.
  //
  Future<ThermionAsset> loadGltf(
    String uri, {
    bool addToScene = true,
    int initialInstances = 1,
    bool releaseSourceData = false,
    bool rebuildVertices = false,
    bool editableVertices = false,
    String? resourceUri,
    bool loadAsync = false,
  });

  // Loads a gltf asset from the specified buffer (which contains the contents
  // of a .glb file).
  //
  // See the [loadGltf] method for documentation on arguments.
  Future<ThermionAsset> loadGltfFromBuffer(
    Uint8List data, {
    String? resourceUri,
    int initialInstances = 1,
    bool releaseSourceData = false,
    bool rebuildVertices = false,
    bool editableVertices = false,
    bool loadResourcesAsync = false,
    bool addToScene = true,
  });

  // Destroys [asset] and all underlying resources
  // (including instances, but excluding any manually created material instances).
  //
  Future destroyAsset(ThermionAsset asset);

  // Removes/destroys all renderable entities from the scene (including cameras).
  // All [ThermionEntity] handles will no longer be valid after this method is
  // called; ensure you immediately discard all references to all entities once
  // this method is complete.
  Future destroyAssets();

  // Enable/disable bloom.
  Future setBloom(bool enabled, double strength);

  // Enables/disables frustum culling.
  Future setViewFrustumCulling(bool enabled);

  // Sets the viewport sizes and updates all cameras to use the new aspect ratio.
  Future setViewport(int width, int height);

  //
  Future setLayerVisibility(VisibilityLayers layer, bool visible);

  //
  // Set the world space position for [lightEntity] to the given coordinates.
  //
  Future setLightPosition(ThermionEntity lightEntity, double x, double y, double z);

  //
  // Sets the world space direction for [lightEntity] to the given vector.
  //
  Future setLightDirection(ThermionEntity lightEntity, Vector3 direction);

  //
  // Enable/disable postprocessing effects (anti-aliasing, tone mapping, bloom). Disabled by default.
  //
  Future setPostProcessing(bool enabled);

  //
  // Enable/disable shadows (disabled by default).
  //
  Future setShadowsEnabled(bool enabled);

  //
  // Set shadow type.
  //
  Future setShadowType(ShadowType shadowType);

  //
  // Set antialiasing options.
  //
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);

  // Sets the draw priority for the given entity. See RenderableManager.h for
  // more details.
  Future setPriority(ThermionEntity entityId, int priority);

  //
  Future<ThermionAsset> createGeometry(Geometry geometry, {List<MaterialInstance>? materialInstances});

  // Returns a gizmo for translating/rotating objects.
  // Only one gizmo can be visible at any given time for this viewer.
  Future<GizmoAsset> getGizmo(GizmoType type);

  // Register a callback to be invoked when this viewer is disposed.
  void onDispose(Future Function() callback);

  // Gets the 3D axis aligned bounding box for the given entity.
  @Deprecated("Call FilamentApp.instance.getRenderableBoundingBox instead")
  Future<Aabb3> getRenderableBoundingBox(ThermionEntity entity);

  // Render the bounding box for [asset] with an unlit material.
  Future showBoundingBox(ThermionAsset asset);

  // Removes the bounding box for [asset] from the scene.
  //
  // If [destroy] is true, the geometry and material instance for the asset
  // will also be destroyed.
  Future hideBoundingBox(ThermionAsset asset, {bool destroy = false});

  // Gets the 2D bounding box (in viewport coordinates) for the given entity.
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity);

  //
  Future setGridOverlayVisibility(
    bool visible, {
    List<LinearColor> axisColors = kDefaultAxisColors,
    LinearColor gridColor = kDefaultGridColor,
    List<double> spacing = const [1.0, 10.0, 100.0],
    List<double> fadeInStart = const [0.001, 5.0, 50.0],
    List<double> fadeInEnd = const [0.001, 50.0, 500.0],
    List<double> fadeOutStart = const [10.0, 500.0, 5000.0],
    List<double> fadeOutEnd = const [200.0, 2000.0, 20000.0],
  });

  /// Shows or hides a translation axis line overlay.
  ///
  /// When [visible] is true, [axis] is required, and either [entity] or [origin] must be provided.
  /// If [entity] is provided, the axis line is positioned at the entity's current world position.
  /// If [origin] is provided, it overrides the entity position.
  /// The line extends [lineLength] in both directions along [axis].
  /// Colors are hardcoded: X=red, Y=green, Z=blue.
  Future setTranslationAxisVisibility(
    bool visible, {
    ThermionEntity? entity,
    Vector3? origin,
    Axis? axis,
    double lineWidth = 5.0,
    double lineLength = 500.0,
  });

  //
  Future<Camera> createCamera();

  //
  Future destroyCamera(covariant Camera camera);

  //
  Future setActiveCamera(covariant Camera camera);

  //
  Future<Camera> getActiveCamera();

  //
  int getCameraCount();

  // Adds the asset to the scene. All renderable entities attached to
  // the asset will be visible.
  Future addToScene(covariant ThermionAsset asset);

  // Removes the asset from the scene. None of the renderable entities
  // attached to the asset will be visible, but the asset itself remains valid.
  Future removeFromScene(covariant ThermionAsset asset);
}
