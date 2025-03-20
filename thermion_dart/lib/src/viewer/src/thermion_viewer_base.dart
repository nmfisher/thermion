import 'package:thermion_dart/src/filament/src/light_options.dart';

import '../../filament/src/shared_types.dart';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'dart:async';

///
/// A (high-level) interface for a 3D scene.
///
/// Use this to add/remove assets, lights and cameras.
///
/// Multiple instances can be created; each will correspond
/// broadly to a single Filament Scene/View.
///
/// If you know yhat you are doing, you can use a lower level interface by
/// using the methods directly via FilamentApp.instance;
///
abstract class ThermionViewer {
  Future<bool> get initialized;

  ///
  ///
  ///
  View get view;

  ///
  /// If [true], this Viewer should render itself
  ///
  bool get rendering;

  ///
  /// Set to true to continuously render the scene at the framerate specified by [setFrameRate] (60 fps by default).
  ///
  Future setRendering(bool render);

  ///
  /// Render a single frame immediately.
  ///
  Future render();

  ///
  ///
  ///
  double get msPerFrame;

  ///
  /// Sets the framerate for continuous rendering when [setRendering] is enabled.
  ///
  Future setFrameRate(int framerate);

  ///
  /// Destroys/disposes the viewer (including the entire scene). You cannot use the viewer after calling this method.
  ///
  Future dispose();

  ///
  /// Set the background image to [path] (which should have a file extension .png, .jpg, or .ktx).
  /// This will be rendered at the maximum depth (i.e. behind all other objects including the skybox).
  /// If [fillHeight] is false, the image will be rendered at its original size. Note this may cause issues with pixel density so be sure to specify the correct resolution
  /// If [fillHeight] is true, the image will be stretched/compressed to fit the height of the viewport.
  ///
  Future setBackgroundImage(String path, {bool fillHeight = false});

  ///
  /// Moves the background image to the relative offset from the origin (bottom-left) specified by [x] and [y].
  /// If [clamp] is true, the image cannot be positioned outside the bounds of the viewport.
  ///
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false});

  ///
  /// Removes the background image.
  ///
  Future clearBackgroundImage();

  ///
  /// Sets the color for the background plane (positioned at the maximum depth, i.e. behind all other objects including the skybox).
  ///
  Future setBackgroundColor(double r, double g, double b, double alpha);

  ///
  /// Load a skybox from [skyboxPath] (which must be a .ktx file)
  ///
  Future loadSkybox(String skyboxPath);

  ///
  /// Removes the skybox from the scene.
  ///
  Future removeSkybox();

  ///
  /// Creates an indirect light by loading the reflections/irradiance from the KTX file.
  /// Only one indirect light can be active at any given time; if an indirect light has already been loaded, it will be replaced.
  ///
  Future loadIbl(String lightingPath, {double intensity = 30000});

  ///
  /// Rotates the IBL & skybox.
  ///
  Future rotateIbl(Matrix3 rotation);

  ///
  /// Removes the image-based light from the scene.
  ///
  Future removeIbl();

  ///
  /// Adds a direct light to the scene.
  /// See LightManager.h for details
  /// Note that [sunAngularRadius] is in degrees,
  /// whereas [spotLightConeInner] and [spotLightConeOuter] are in radians
  ///
  Future<ThermionEntity> addDirectLight(DirectLight light);

  ///
  /// Remove a light from the scene.
  ///
  Future removeLight(ThermionEntity light);

  ///
  /// Remove all lights (excluding IBL) from the scene.
  ///
  Future destroyLights();

  ///
  /// Load the .glb asset at the given path, adding all entities to the scene.
  /// Specify [numInstances] to create multiple instances (this is more efficient than dynamically instantating at a later time). You can then retrieve the created instances with [getInstances].
  /// If you want to be able to call [createInstance] at a later time, you must pass true for [keepData].
  /// If [keepData] is false, the source glTF data will be released and [createInstance] will throw an exception.
  ///
  Future<ThermionAsset> loadGlb(String path,
      {int numInstances = 1,
      bool keepData = false,
      String relativeResourcePath});

  ///
  /// Load the .glb asset from the specified buffer, adding all entities to the scene.
  /// Specify [numInstances] to create multiple instances (this is more efficient than dynamically instantating at a later time). You can then retrieve the created instances with [getInstances].
  /// If you want to be able to call [createInstance] at a later time, you must pass true for [keepData].
  /// If [keepData] is false, the source glTF data will be released and [createInstance] will throw an exception.
  /// If [loadResourcesAsync] is true, resources (textures, materials, etc) will
  /// be loaded asynchronously (so expect some material/texture pop-in);
  ///
  ///
  Future<ThermionAsset> loadGlbFromBuffer(Uint8List data,
      {int numInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync = false,
      String relativeResourcePath});

  ///
  /// Destroys [asset] and all underlying resources
  /// (including instances, but excluding any manually created material instances).
  ///
  Future destroyAsset(ThermionAsset asset);

  ///
  /// Removes/destroys all renderable entities from the scene (including cameras).
  /// All [ThermionEntity] handles will no longer be valid after this method is called; ensure you immediately discard all references to all entities once this method is complete.
  ///
  Future destroyAssets();

  ///
  /// Sets the tone mapping (requires postprocessing).
  ///
  Future setToneMapping(ToneMapper mapper);

  ///
  /// Enable/disable bloom.
  ///
  Future setBloom(bool enabled, double strength);

  ///
  /// Enables/disables frustum culling.
  ///
  Future setViewFrustumCulling(bool enabled);

  ///
  /// Set the world space position for [lightEntity] to the given coordinates.
  ///
  Future setLightPosition(
      ThermionEntity lightEntity, double x, double y, double z);

  ///
  /// Sets the world space direction for [lightEntity] to the given vector.
  ///
  Future setLightDirection(ThermionEntity lightEntity, Vector3 direction);

  ///
  /// Enable/disable postprocessing effects (anti-aliasing, tone mapping, bloom). Disabled by default.
  ///
  Future setPostProcessing(bool enabled);

  ///
  /// Enable/disable shadows (disabled by default).
  ///
  Future setShadowsEnabled(bool enabled);

  ///
  /// Set shadow type.
  ///
  Future setShadowType(ShadowType shadowType);

  ///
  /// Set soft shadow options (ShadowType DPCF and PCSS)
  ///
  Future setSoftShadowOptions(double penumbraScale, double penumbraRatioScale);

  ///
  /// Set antialiasing options.
  ///
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);

  ///
  /// Hit test the viewport at the given coordinates. If the coordinates intersect
  /// with a renderable entity, [resultHandler] will be called.
  /// This is asynchronous and will require 2-3 frames to complete (so ensure you are calling render())
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the ThermionWidget).
  ///
  Future pick(int x, int y, void Function(PickResult) resultHandler);

  ///
  /// Sets the draw priority for the given entity. See RenderableManager.h for more details.
  ///
  Future setPriority(ThermionEntity entityId, int priority);

  ///
  ///
  ///
  Future<ThermionAsset> createGeometry(Geometry geometry,
      {List<MaterialInstance>? materialInstances, bool keepData = false});

  ///
  /// The gizmo for translating/rotating objects. Only one gizmo can be active for a given view.
  ///
  Future<GizmoAsset> createGizmo(covariant View view, GizmoType type);

  ///
  /// Register a callback to be invoked when this viewer is disposed.
  ///
  void onDispose(Future Function() callback);

  ///
  /// Gets the 3D axis aligned bounding box for the given entity.
  ///
  Future<Aabb3> getRenderableBoundingBox(ThermionEntity entity);

  ///
  /// Gets the 2D bounding box (in viewport coordinates) for the given entity.
  ///
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity);

  ///
  ///
  ///
  Future showGridOverlay();

  ///
  ///
  ///
  Future removeGridOverlay();

  ///
  ///
  ///
  Future<Camera> createCamera();

  ///
  ///
  ///
  Future destroyCamera(covariant Camera camera);

  ///
  ///
  ///
  Future setActiveCamera(covariant Camera camera);

  ///
  ///
  ///
  Future<Camera> getActiveCamera();

  ///
  ///
  ///
  int getCameraCount();

  Future addToScene(covariant ThermionAsset asset);
  Future removeFromScene(covariant ThermionAsset asset);
}
