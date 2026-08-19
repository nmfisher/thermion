import 'package:thermion_dart/src/filament/src/interface/animation_manager.dart';
import 'package:thermion_dart/src/filament/src/interface/render_manager.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FilamentConfig<T, U> {
  final Backend backend;
  Future<Uint8List> Function(String)? loadResource;
  final U? platform;
  final U? sharedContext;
  final String? uberArchivePath;
  final int stereoscopicEyeCount;
  final bool disableHandleUseAfterFreeCheck;

  FilamentConfig({
    required this.backend,
    required this.loadResource,
    this.uberArchivePath,
    this.platform,
    this.sharedContext,
    this.stereoscopicEyeCount = 1,
    this.disableHandleUseAfterFreeCheck = false,
  });
}

abstract class FilamentApp<T> {
  static FilamentApp? instance;

  /// A handle to the native Filament Engine instance attached to this application.
  Pointer<TEngine> get engine;
  T get gltfAssetLoader;
  T get renderer;
  AnimationManager<T> get animationManager;
  TransformManager get transformManager;

  T get ubershaderMaterialProvider;
  RenderableManager get renderableManager;
  RenderManager get renderManager;
  LightManager get lightManager;
  DebugRegistry getDebugRegistry();
  int getMaxAutomaticInstances();
  void setAutomaticInstancingEnabled(bool enabled);

  //
  Future<Uint8List> loadResource(String uri);

  //
  Future<SwapChain> createHeadlessSwapChain(int width, int height, {bool hasStencilBuffer = false});

  //
  Future<SwapChain> createSwapChain(T handle, {bool hasStencilBuffer = false});

  //
  Future<View> createView({bool createScene = false});

  //
  Future<Scene> createScene();

  // Creates a new Camera component. If [targetEntity] is null, a new entity
  // will be created; otherwise, the component will be attached to
  // [targetEntity].
  Future<Camera> createCamera({ThermionEntity? targetEntity});

  // Destroys the specified entity. You must ensure that the entity has already
  // been detached (e.g. if renderable, it has been removed from any scenes,
  // that any camera or animation component has already been removed, etc).
  Future destroyEntity(ThermionEntity entity);

  //
  Future destroySwapChain(SwapChain swapChain);

  //
  Future destroyView(View view);

  //
  Future destroyScene(Scene scene);

  //
  Future destroy();

  //
  Future destroyAsset(covariant ThermionAsset asset);

  //
  Future<RenderTarget> createRenderTarget(int width, int height, {covariant Texture? color, covariant Texture? depth});

  //
  Future<Texture> createTexture(
    int width,
    int height, {
    int depth = 1,
    int levels = 1,
    Set<TextureUsage> flags = const {TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
    TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
    TextureFormat textureFormat = TextureFormat.RGBA32F,
    int? importedTextureHandle,
  });

  Future<void> setExternalImage(Texture texture, int externalImagePtr);

  //
  Future<TextureSampler> createTextureSampler({
    TextureMinFilter minFilter = TextureMinFilter.LINEAR,
    TextureMagFilter magFilter = TextureMagFilter.LINEAR,
    TextureWrapMode wrapS = TextureWrapMode.CLAMP_TO_EDGE,
    TextureWrapMode wrapT = TextureWrapMode.CLAMP_TO_EDGE,
    TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE,
    double anisotropy = 0.0,
    TextureCompareMode compareMode = TextureCompareMode.NONE,
    TextureCompareFunc compareFunc = TextureCompareFunc.LESS_EQUAL,
  });

  /// Decodes [data] into a caller-owned [LinearImage].
  ///
  /// The caller must eventually call [LinearImage.destroy].
  Future<LinearImage> decodeImage(Uint8List data, {String name = "image", bool requireAlpha = false});

  /// Creates a caller-owned empty [LinearImage] with the given dimensions.
  ///
  /// The caller must eventually call [LinearImage.destroy].
  Future<LinearImage> createImage(int width, int height, int channels);

  //
  Future<Material> createGizmoMaterial();

  Future<Material> createBoneOverlayMaterial();

  //
  Future<Material> createMaterial(Uint8List data);

  /// Compiles .mat [matSource] into a .filamat package at runtime — the
  /// same container [createMaterial] accepts — using the Filament material
  /// compiler linked into the engine library (matc's pipeline: parse the
  /// material definition, generate + optimize shaders for the target).
  ///
  /// Phase 1 of docs/research/runtime-material-compile.md. Currently
  /// supported on desktop (linux/macOS/Windows); other platforms throw
  /// [UnsupportedError].
  ///
  /// [targetApi] selects which graphics APIs the package carries shaders
  /// for; null derives it from the engine's active backend (recommended, and
  /// what a reload-and-continue workflow wants). [platform] defaults to
  /// generating both desktop and mobile variants. [optimization] mirrors
  /// matc's -O flags (default PERFORMANCE, like release materials).
  ///
  /// [defines] are passed to the shader preprocessor (matc's -D). [matSource]
  /// must not contain unresolved #include directives: [includePaths] lists
  /// directories to resolve them from, and includes are flattened by this
  /// library before compiling (circular includes are an error).
  ///
  /// [embedSource] controls whether the .mat source is embedded in the
  /// package (matc's -e / no-embed-source); embedded source makes packages
  /// self-describing for tooling at a small size cost.
  ///
  /// Throws [MaterialCompileException] with the compiler's message when the
  /// source fails to parse or the shaders fail to build.
  Future<Uint8List> compileMaterial(
    String matSource, {
    MaterialCompilePlatform platform = MaterialCompilePlatform.all,
    Set<MaterialTargetApi>? targetApi,
    MaterialOptimization optimization = MaterialOptimization.performance,
    Map<String, String> defines = const {},
    List<String> includePaths = const [],
    bool embedSource = true,
  });

  //
  Future<MaterialInstance> createUbershaderMaterialInstance({
    bool doubleSided = false,
    bool unlit = false,
    bool hasVertexColors = false,
    bool hasBaseColorTexture = false,
    bool hasNormalTexture = false,
    bool hasOcclusionTexture = false,
    bool hasEmissiveTexture = false,
    bool useSpecularGlossiness = false,
    AlphaMode alphaMode = AlphaMode.OPAQUE,
    bool enableDiagnostics = false,
    bool hasMetallicRoughnessTexture = false,
    int metallicRoughnessUV = -1,
    int baseColorUV = -1,
    bool hasClearCoatTexture = false,
    int clearCoatUV = -1,
    bool hasClearCoatRoughnessTexture = false,
    int clearCoatRoughnessUV = -1,
    bool hasClearCoatNormalTexture = false,
    int clearCoatNormalUV = -1,
    bool hasClearCoat = false,
    bool hasTransmission = false,
    bool hasTextureTransforms = false,
    int emissiveUV = -1,
    int aoUV = -1,
    int normalUV = -1,
    bool hasTransmissionTexture = false,
    int transmissionUV = -1,
    bool hasSheenColorTexture = false,
    int sheenColorUV = -1,
    bool hasSheenRoughnessTexture = false,
    int sheenRoughnessUV = -1,
    bool hasVolumeThicknessTexture = false,
    int volumeThicknessUV = -1,
    bool hasSheen = false,
    bool hasIOR = false,
    bool hasVolume = false,
  });

  /// Creates an ubershader material instance wrapped in a typed
  /// [UbershaderMaterialInstance] with named setters for all standard PBR
  /// parameters.
  Future<UbershaderMaterialInstance> createUbershaderMaterial({
    bool doubleSided = false,
    bool unlit = false,
    bool hasVertexColors = false,
    bool hasBaseColorTexture = false,
    bool hasNormalTexture = false,
    bool hasOcclusionTexture = false,
    bool hasEmissiveTexture = false,
    bool useSpecularGlossiness = false,
    AlphaMode alphaMode = AlphaMode.OPAQUE,
    bool enableDiagnostics = false,
    bool hasMetallicRoughnessTexture = false,
    int metallicRoughnessUV = -1,
    int baseColorUV = -1,
    bool hasClearCoatTexture = false,
    int clearCoatUV = -1,
    bool hasClearCoatRoughnessTexture = false,
    int clearCoatRoughnessUV = -1,
    bool hasClearCoatNormalTexture = false,
    int clearCoatNormalUV = -1,
    bool hasClearCoat = false,
    bool hasTransmission = false,
    bool hasTextureTransforms = false,
    int emissiveUV = -1,
    int aoUV = -1,
    int normalUV = -1,
    bool hasTransmissionTexture = false,
    int transmissionUV = -1,
    bool hasSheenColorTexture = false,
    int sheenColorUV = -1,
    bool hasSheenRoughnessTexture = false,
    int sheenRoughnessUV = -1,
    bool hasVolumeThicknessTexture = false,
    int volumeThicknessUV = -1,
    bool hasSheen = false,
    bool hasIOR = false,
    bool hasVolume = false,
  }) async {
    final mi = await createUbershaderMaterialInstance(
      doubleSided: doubleSided,
      unlit: unlit,
      hasVertexColors: hasVertexColors,
      hasBaseColorTexture: hasBaseColorTexture,
      hasNormalTexture: hasNormalTexture,
      hasOcclusionTexture: hasOcclusionTexture,
      hasEmissiveTexture: hasEmissiveTexture,
      useSpecularGlossiness: useSpecularGlossiness,
      alphaMode: alphaMode,
      enableDiagnostics: enableDiagnostics,
      hasMetallicRoughnessTexture: hasMetallicRoughnessTexture,
      metallicRoughnessUV: metallicRoughnessUV,
      baseColorUV: baseColorUV,
      hasClearCoatTexture: hasClearCoatTexture,
      clearCoatUV: clearCoatUV,
      hasClearCoatRoughnessTexture: hasClearCoatRoughnessTexture,
      clearCoatRoughnessUV: clearCoatRoughnessUV,
      hasClearCoatNormalTexture: hasClearCoatNormalTexture,
      clearCoatNormalUV: clearCoatNormalUV,
      hasClearCoat: hasClearCoat,
      hasTransmission: hasTransmission,
      hasTextureTransforms: hasTextureTransforms,
      emissiveUV: emissiveUV,
      aoUV: aoUV,
      normalUV: normalUV,
      hasTransmissionTexture: hasTransmissionTexture,
      transmissionUV: transmissionUV,
      hasSheenColorTexture: hasSheenColorTexture,
      sheenColorUV: sheenColorUV,
      hasSheenRoughnessTexture: hasSheenRoughnessTexture,
      sheenRoughnessUV: sheenRoughnessUV,
      hasVolumeThicknessTexture: hasVolumeThicknessTexture,
      volumeThicknessUV: volumeThicknessUV,
      hasSheen: hasSheen,
      hasIOR: hasIOR,
      hasVolume: hasVolume,
    );
    final ubershader = UbershaderMaterialInstance(mi);
    if (hasBaseColorTexture) {
      await ubershader.setBaseColorFactor(1.0, 1.0, 1.0, 1.0);
    }
    return ubershader;
  }

  //
  Future<MaterialInstance> createUnlitMaterialInstance();

  /// Creates a wireframe material instance for use with assets loaded
  /// with [rebuildVertices: true]. Set parameters (edgeColor, faceColor,
  /// edgeWidth) on the returned [WireframeMaterialInstance], then apply with
  /// [ThermionAsset.setMaterialInstanceForAll].
  Future<WireframeMaterialInstance> createWireframeMaterialInstance();

  //
  Future<MaterialInstance> getMaterialInstanceAt(ThermionEntity entity, int primitiveIndex);

  //
  Future setMaterialInstanceAt(ThermionEntity entity, int primitiveIndex, MaterialInstance materialInstance);

  /// Replaces [oldMaterial] with a [Material] built from [materialBytes]
  /// (the same container [createMaterial] accepts), keeping renderables
  /// visually continuous.
  ///
  /// This is the reload path from the runtime-material-compile design
  /// (docs/research/runtime-material-compile.md, section 4.1): Filament does
  /// not allow re-parenting a MaterialInstance to another Material, so the
  /// swap is: build the new material, create one replacement instance per
  /// distinct instance of the old material, replay each old instance's
  /// recorded state onto its replacement, point every affected renderable
  /// primitive at the replacement, then destroy the old instances and the old
  /// material on the render thread.
  ///
  /// Parameter and raster state are replayed from the shadow recording kept
  /// by the MaterialInstance wrappers: every setParameter*/set* call made
  /// through this library is captured. Values set only through native code
  /// (none today) or parameters relying on the material's declared defaults
  /// cannot be recovered; instances whose state was never touched are
  /// re-created with the new material's defaults.
  ///
  /// Set [destroyOld] to false to keep the old material alive (e.g. to fade
  /// between materials yourself); you then own it and its instances.
  Future<Material> reloadMaterialFromBytes(Material oldMaterial, Uint8List materialBytes, {bool destroyOld = true});

  /// Returns every renderable primitive, across all scenes, currently drawn
  /// with an instance of [material] — including instances attached by asset
  /// loaders outside this library (found by scanning the scene) and instances
  /// attached via [setMaterialInstanceAt] that are not yet in a scene
  /// (found from the app's own records).
  ///
  /// This is the entity-scan helper of the reload design (section 4.1, L2).
  /// It is exposed separately from [reloadMaterialFromBytes] because callers
  /// may want the list of affected entities for their own bookkeeping (for
  /// example to re-run per-entity material setup after a reload).
  Future<List<MaterialInstanceUse>> findRenderablesUsingMaterial(Material material);



  // Returns all valid swapchains.
  Future<Iterable<SwapChain>> getSwapChains();

  // Invokes one iteration of the full rendering pipeline for all
  // registered swapchains/views. This will also advance animations
  // by one timestep and call out to all plugins to perform their own updates.
  //
  // The returned [Future] will complete when the pipeline step is complete.
  Future render();

  /// Caps the continuous-render framerate to [fps].
  ///
  /// If never called, the viewer renders on every vsync — at the display's
  /// native refresh rate (60 fps on a 60 Hz panel, 120 on a 120 Hz panel,
  /// and so on). The cap cannot raise the rate above the display refresh; it
  /// only lowers it by skipping vsyncs or render requests. When the display
  /// refresh is not an integer multiple of [fps], presentation intervals vary
  /// as needed to preserve the requested average rate.
  ///
  /// Framerate is a property of the *shared* render loop, not of any one
  /// viewer: all viewers on the same engine are pace-locked to the same rate
  /// (last writer wins). Values <= 0 remove the cap.
  void setTargetFramerate(int fps);

  //
  Future registerRequestFrameHook(Future Function() hook);

  //
  Future unregisterRequestFrameHook(Future Function() hook);

  // Retrieves the name assigned to the given entity (usually corresponds to the
  // glTF mesh name).
  String? getNameForEntity(ThermionEntity entity);

  // Gets the parent entity of [entity]. Returns null if the entity has no
  // parent.
  Future<ThermionEntity?> getParent(ThermionEntity entity);

  // Gets the ancestor (ultimate parent) entity of [entity]. Returns null if the
  // entity has no parent.
  Future<ThermionEntity?> getAncestor(ThermionEntity entity);

  // Sets the parent transform of [child] to [parent].
  //
  Future setParent(ThermionEntity child, ThermionEntity? parent, {bool preserveScaling});

  //
  // Returns pixel buffer(s) for [view] (or, if null, all views associated
  // with [swapChain] by calling [register]).
  //
  // Pixel buffers will be returned in RGBA float32 format.
  //
  Future<List<(View, Uint8List)>> capture(
    SwapChain? swapChain, {
    View? view,
    bool captureRenderTarget = false,
    PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
    PixelDataType pixelDataType = PixelDataType.FLOAT,
    Future Function(View)? beforeRender,
    bool render = true,
  });

  //
  Future setClearOptions(
    double r,
    double g,
    double b,
    double a, {
    int clearStencil = 0,
    bool discard = false,
    bool clear = true,
  });

  // Loads a glTF asset from a raw memory buffer.
  Future<ThermionAsset> loadGltfFromBuffer(
    Uint8List data, {
    int initialInstances = 1,
    bool releaseSourceData = false,
    bool rebuildVertices = false,
    bool loadResourcesAsync = false,
    String? resourceUri,
  });

  //
  Future<GizmoAsset> createGizmo(View view, GizmoType type);

  //
  Future<ThermionAsset> createGeometry(Geometry geometry, {List<MaterialInstance>? materialInstances});

  //
  Future<ThermionEntity> createDirectLight(DirectLight directLight);

  //
  Future flush();

  /// Registers work that must finish before engine-owned render resources are
  /// torn down.
  void onBeforeDestroy(Future Function() callback);

  //
  void onDestroy(Future Function() callback);

  //
  Future<ThermionEntity> createEntity({bool createTransformComponent = true});

  //
  Future setTransform(ThermionEntity entity, Matrix4 transform);

  // Gets the current transform for [entity] in local space (relative to its
  // parent).
  Future<Matrix4> getLocalTransform(ThermionEntity entity);

  // Gets the current transform for [entity] in world space.
  Future<Matrix4> getWorldTransform(ThermionEntity entity);

  // Sets the render priority for [entity].
  // [priority] should be be between 0 and 7, with 0 meaning highest priority
  // (rendered first) and 7 meaning lowest priority (rendered last).
  Future setPriority(ThermionEntity entity, int priority);

  // Gets the number of primitives for [entity] (which is assumed to be
  // have a renderable component attached)
  //
  Future<int> getPrimitiveCount(ThermionEntity entity);

  // Gets the bounding box for [entity] (which is assumed to be
  // have a renderable component attached).
  //
  Future<Aabb3> getBoundingBox(ThermionEntity entity);

  // Builds a [Skybox] instance. This will not be attached to any scene until
  // [setSkybox] is called.
  //
  // [showSun] renders the sun (requires a SUN light in the scene; off by
  // default). [intensity] scales the skybox texel values to lux/lumen-m^2
  // (Filament's default of 30000 is used when null). [priority] is the
  // rendering priority, clamped by Filament to [0..7] (7 = lowest priority,
  // rendered last; the default).
  //
  Future<Skybox> buildSkybox({Texture? texture = null, bool showSun = false, double? intensity, int priority = 7});

  // Creates a [Skybox] with a solid color. This will not be attached to any
  // scene until [setSkybox] is called.
  //
  // This is useful for clearing render targets with a specific color
  // (including fully transparent for overlay passes).
  //
  // [showSun] renders the sun (requires a SUN light in the scene; off by
  // default). [intensity] scales the skybox color to lux/lumen-m^2
  // (Filament's default of 30000 is used when null). [priority] is the
  // rendering priority, clamped by Filament to [0..7] (7 = lowest priority,
  // rendered last; the default).
  Future<Skybox> createColoredSkybox({
    required double r,
    required double g,
    required double b,
    required double a,
    bool showSun = false,
    double? intensity,
    int priority = 7,
  });

  //
  Future<bool> isRenderable(ThermionEntity entity);

  // Create a [Texture] from the content of a KTX2 file containing
  // BasisU-encoded data. Even though the KTX2 format does not mandate BasisU
  // compression, the Filament implementation uses BasisU to decode KTX2 data
  // (which will fail if you pass an uncompressed KTX2 file).
  //
  Future<Texture> loadKtx2(Uint8List data);

  // Create a screenspace quad. This can be used as an image or a solid block.
  Future<TexturedQuad> createTexturedQuad();

  // Parse glTF file and extract geometry data for physics collision detection.
  // Returns vertex positions (xyz) and optional indices.
  // If [meshName] is specified, only extracts data for that specific mesh.
  Future<GltfMeshData> parseGltf(Uint8List data, {String? meshName});
}

/// One hit from [FilamentApp.findRenderablesUsingMaterial]: a renderable
/// primitive currently drawn with a material instance that belongs to a given
/// material.
class MaterialInstanceUse {
  /// The renderable entity. Combine with [primitiveIndex] for
  /// [FilamentApp.setMaterialInstanceAt].
  final ThermionEntity entity;

  /// Which primitive of [entity]'s renderable uses the material instance.
  final int primitiveIndex;

  /// The instance in use. After a material reload this refers to a retired
  /// instance; re-fetch uses from the app instead of caching them.
  final MaterialInstance materialInstance;

  MaterialInstanceUse(this.entity, this.primitiveIndex, this.materialInstance);
}

/// Which platform flavor of shaders a runtime compile generates
/// (matc's -g/-p selection). Mirrors filamat's Platform.
enum MaterialCompilePlatform { desktop, mobile, all }

/// Which graphics API a runtime compile generates shaders for (matc's -a).
/// Pass a Set to generate several; omit [FilamentApp.compileMaterial]'s
/// targetApi to derive it from the engine's backend.
enum MaterialTargetApi { opengl, vulkan, metal, webgpu }

/// Optimization level for a runtime compile (matc's -O).
enum MaterialOptimization { none, preprocessor, size, performance }

/// Thrown by [FilamentApp.compileMaterial] when the .mat source fails to
/// parse or its shaders fail to build. The message comes from the compiler.
class MaterialCompileException implements Exception {
  final String message;

  MaterialCompileException(this.message);

  @override
  String toString() => "MaterialCompileException: $message";
}
