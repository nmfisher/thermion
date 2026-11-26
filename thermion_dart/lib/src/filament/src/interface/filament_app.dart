import 'package:thermion_dart/src/filament/src/interface/animation_manager.dart';
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

/// Compile-time features of the loaded Thermion build.
///
/// Each one can be switched off when building the consuming app, under
/// `hooks.user_defines.thermion_dart.features` in its pubspec.yaml (all on
/// by default; see "Compile-time feature opt-outs" in the package README):
///
/// ```yaml
/// hooks:
///   user_defines:
///     thermion_dart:
///       features:
///         gltf: false            # glTF loading, glTF animation, ubershader materials
///         ktx: false             # KTX1/KTX2 (incl. Basis) textures
///         image_decoding: false  # PNG/JPEG decoding
/// ```
///
/// [FilamentApp.supports] reports which of them the loaded library has.
/// APIs that need a disabled feature throw [UnsupportedError] naming the
/// `features.*` key instead of failing deeper in the FFI layer.
enum ThermionFeature {
  /// glTF loading ([FilamentApp.loadGltfFromBuffer]), glTF clip and bone
  /// animation and the gltfio ubershader materials
  /// ([FilamentApp.createUbershaderMaterialInstance]). Procedural geometry
  /// keeps working without it: [FilamentApp.createUnlitMaterialInstance]
  /// uses a precompiled unlit material in such builds, and custom morph
  /// animation keeps working too through
  /// [AnimationManager.setMorphAnimation]/[AnimationManager.clearMorphAnimation]
  /// — the entity-keyed morph buffer does not use gltfio. The asset-level
  /// [ThermionAsset.setMorphAnimationData] matches morph targets by their
  /// glTF names, so it needs glTF support.
  gltf,

  /// KTX1/KTX2 textures including Basis Universal ([FilamentApp.loadKtx2],
  /// `loadKtx`/`createIblFromKtx` on the viewer).
  ktx,

  /// PNG/JPEG decoding for [FilamentApp.decodeImage]; `createImage` and
  /// `Texture.setLinearImage` are unaffected.
  imageDecoding,

  /// Runtime material compilation (`runtime_materials`); mirrors
  /// [FilamentApp.runtimeMaterialsSupported].
  runtimeMaterials,
}

abstract class FilamentApp<T> {
  static FilamentApp? instance;

  /// Whether the loaded build includes [feature].
  ///
  /// Read once from the native library at startup
  /// (`Thermion_getEnabledFeatures`), so the answer never changes for the
  /// lifetime of the process. Web engines are prebuilt with every feature;
  /// an engine older than the probe reports all features enabled.
  bool supports(ThermionFeature feature);

  /// A handle to the native Filament Engine instance attached to this application.
  Pointer<TEngine> get engine;

  /// The backend this app was created with (e.g. [Backend.WEBGPU] when the
  /// Dawn-backed WebGPU path is enabled).
  Backend get backend;

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

  /// Creates a swapchain presenting to [handle] (a native window, or the
  /// viewer canvas on web).
  ///
  /// For offscreen (present-skip) swapchains whose frames JavaScript
  /// composites itself, see the web-only entrypoint
  /// `package:thermion_dart/thermion_dart_web.dart`.
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

  /// Destroys [asset] and its instances (if any). The asset/instances will immediately be inaccessible.
  /// Throws [StateError] if destruction has already started for the asset or its owner.
  Future destroyAsset(covariant ThermionAsset asset);

  /// Creates a [RenderTarget] of size [width] x [height].
  ///
  /// If [color] is omitted, an `RGBA8` color attachment texture is allocated
  /// automatically with sampleable, color-attachment, and blit-source usage.
  ///
  /// If [depth] is omitted and [createDepth] is `true` (the default), a
  /// `DEPTH32F` depth attachment texture is allocated automatically. Pass
  /// `createDepth: false` (with `depth: null`) to create a color-only render
  /// target without a depth attachment.
  Future<RenderTarget> createRenderTarget(
    int width,
    int height, {
    covariant Texture? color,
    covariant Texture? depth,
    bool createDepth = true,
  });

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

  /// Creates a caller-owned material from an embedded helper package.
  /// Destroy its instances before destroying the material. Throws [StateError]
  /// if the build omits the selected package.
  ///
  /// [BuiltInMaterial.unlitFallback] is not selectable here: it is the
  /// internal fallback behind [createUnlitMaterialInstance] in
  /// `features.gltf: false` builds. Requesting it throws [StateError]
  /// directing you to [createUnlitMaterialInstance].
  Future<Material> createBuiltInMaterial(BuiltInMaterial material);

  /// Material package format version expected by the loaded native build.
  ///
  /// This is the number reported by `matc --version`, distinct from the
  /// Filament release version.
  int get materialVersion;

  /// Creates a material from a compiled `.filamat` package. Native code copies
  /// [data] before queuing the build, so the caller can reuse it after this call.
  ///
  /// Throws [FormatException] for malformed chunk boundaries, missing or invalid
  /// version metadata, or a format version different from [materialVersion].
  /// Compile materials with `matc` from the same Filament release as the application.
  ///
  /// This checks the package layout and version, not every payload or backend
  /// requirement. Other invalid packages can still cause a native Filament panic.
  Future<Material> createMaterial(Uint8List data);

  /// Whether the loaded native build supports compiling materials from
  /// source at runtime (the `runtime_materials` build flag; the same fact as
  /// `supports(ThermionFeature.runtimeMaterials)`, kept for compatibility).
  ///
  /// False when the app was built without the flag — including the default
  /// web engine (the filamat-enabled web variant reports true). When false,
  /// [compileMaterialSource] and [compileMaterialPackage] throw
  /// [UnsupportedError]; use `matc`-compiled `.filamat` packages with
  /// [createMaterial] instead.
  bool get runtimeMaterialsSupported;

  /// Compiles GLSL material [source] to a `.filamat` package at runtime and
  /// creates a [Material] from it.
  ///
  /// [source] is the GLSL of the `material()` function, the same format
  /// accepted by `MaterialBuilder::material()`:
  ///
  /// ```glsl
  /// void material(inout MaterialInputs material) {
  ///   prepareMaterial(material);
  ///   material.baseColor.rgb = float3(1.0, 0.0, 0.0);
  /// }
  /// ```
  ///
  /// [name] labels the material in diagnostics and generated shader names.
  /// [shading] selects the lighting model.
  ///
  /// Throws [UnsupportedError] when [runtimeMaterialsSupported] is false
  /// (builds without the `runtime_materials` flag, incl. the default web
  /// engine). Compile failures are logged through the Filament logger and
  /// rethrown as a [StateError].
  ///
  /// This is a synchronous, CPU-intensive native call (hundreds of ms).
  /// Prefer calling before startup or from a background isolate.
  Future<Material> compileMaterialSource(String name, String source, {MaterialShading shading = MaterialShading.lit});

  /// Compiles a full `.mat` material package [source] at runtime — the same
  /// format the `matc` tool accepts — and creates a [Material] from it.
  ///
  /// Unlike [compileMaterialSource] (bare `material()` GLSL), [source] is a
  /// complete `.mat` file with a `material { ... }` configuration block
  /// (name, shading model, parameters, variants, ...), optional
  /// `vertex { ... }` code and a `fragment { ... }` block:
  ///
  /// ```
  /// material {
  ///     name : "MyMaterial",
  ///     shadingModel : unlit,
  ///     parameters : [ { type : float4, name : baseColor } ]
  /// }
  /// fragment {
  ///     void material(inout MaterialInputs material) {
  ///         prepareMaterial(material);
  ///         material.baseColor = materialParams.baseColor;
  ///     }
  /// }
  /// ```
  ///
  /// [includes] optionally maps include names to file contents. Every
  /// `#include "name"` directive in [source] (and in included files) is
  /// resolved against this map by exact name; there is no filesystem
  /// access. Unresolvable includes fail the compile.
  ///
  /// [name] labels the material in diagnostics. All other compilation
  /// settings (shading model, parameters, blending, ...) come from the
  /// `.mat` source itself.
  ///
  /// Throws [UnsupportedError] when [runtimeMaterialsSupported] is false,
  /// and [ArgumentError] for an empty [source]. Include-resolution, parse
  /// and compile failures are logged through the Filament logger and
  /// rethrown as a [StateError].
  ///
  /// This is a synchronous, CPU-intensive native call (hundreds of ms).
  /// Prefer calling before startup or from a background isolate.
  Future<Material> compileMaterialPackage(String name, String source, {Map<String, String>? includes});

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
  /// with the required barycentric geometry capability. Set parameters (edgeColor, faceColor,
  /// edgeWidth) on the returned [WireframeMaterialInstance], then apply with
  /// [ThermionAsset.setMaterialInstanceForAll].
  Future<WireframeMaterialInstance> createWireframeMaterialInstance();

  //
  Future<MaterialInstance> getMaterialInstanceAt(ThermionEntity entity, int primitiveIndex);

  //
  Future setMaterialInstanceAt(ThermionEntity entity, int primitiveIndex, MaterialInstance materialInstance);

  // Returns all valid swapchains.
  Future<Iterable<SwapChain>> getSwapChains();

  /// Renders all registered swapchains/views and updates animations and plugins.
  ///
  /// On native platforms, [frameTimeInNanos] is a frame timestamp in nanoseconds
  /// on the native steady clock, as supplied by Thermion's frame scheduler.
  /// It is not a date, wall-clock time, or Flutter's adjusted animation time.
  /// When omitted, uses the current native steady-clock time. The returned
  /// [Future] completes when the render pipeline step has finished.
  ///
  /// On web, rendering runs independently on the worker's animation frames.
  /// This method returns immediately without requesting or waiting for a frame;
  /// [frameTimeInNanos] is ignored.
  Future render({int? frameTimeInNanos});

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

  /// Returns timing for up to [count] of the most recent frames the renderer
  /// has processed, newest first.
  ///
  /// GPU times cover only Filament's work, so they include rendering into a
  /// texture that a platform view displays, which platform frame timings
  /// leave out. The renderer keeps a short history, so fewer than [count]
  /// frames can be returned, and a frame appears only after the GPU reports
  /// its timing, a few frames after it was rendered.
  ///
  /// Throws [RangeError] when [count] is less than 1, or when a timing value
  /// cannot be represented exactly as an integer on web.
  Future<List<FrameTimingInfo>> getFrameInfoHistory({int count = 1});

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

  /// Returns pixel buffer(s) for [view], or, when [view] is null, for the
  /// renderable views attached to [swapChain] (in attachment order).
  ///
  /// When [view] is provided it is captured even if it is not attached to
  /// [swapChain], and even if its attachment is currently non-renderable:
  /// an explicit request renders that view when [render] is true. When
  /// [view] is null, non-renderable attachments are skipped entirely (no
  /// [beforeRender] callback, no render, no readback), because their targets
  /// hold stale contents and swapchain-bound views would return duplicate
  /// pixels.
  ///
  /// [beforeRender] is awaited once per captured view before its render (when
  /// [render] is true) and readback. When [render] is false, the current
  /// contents are read back without rendering: the view's render target if it
  /// has one, otherwise the swapchain's framebuffer.
  ///
  /// Each view reads from its own render target when it has one, otherwise
  /// from [swapChain]'s framebuffer.
  ///
  /// Pixel buffers will be returned in RGBA float32 format.
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

  /// Loads a glTF asset from a raw memory buffer.
  ///
  /// [requiredGeometryCapabilities] describes the geometry properties that the loaded
  /// asset must support. The loader may provide a compatible superset, which
  /// is reported by [ThermionAsset.geometryCapabilities]. Incompatible
  /// requirements throw [ArgumentError]. Throws [UnsupportedError] when
  /// `supports(ThermionFeature.gltf)` is false.
  Future<ThermionAsset> loadGltfFromBuffer(
    Uint8List data, {
    int initialInstances = 1,
    bool releaseSourceData = false,
    Set<SceneAssetGeometryCapability> requiredGeometryCapabilities = const {},
    bool loadResourcesAsync = false,
    String? resourceUri,
  });

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
  // Requires features.gltf (the native cgltf parser ships with gltfio):
  // throws UnsupportedError when gltf is disabled in this build.
  Future<GltfMeshData> parseGltf(Uint8List data, {String? meshName});
}
