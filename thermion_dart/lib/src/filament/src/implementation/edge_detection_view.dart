import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Manages the edge detection pass for outline rendering.
///
/// Renders a fullscreen quad that samples the silhouette texture and
/// draws outlines where edges are detected.
///
/// Extends [FFIView] directly to inherit all view functionality.
class EdgeDetectionView extends FFIView {
  final _logger = Logger('EdgeDetectionView');

  // Outline settings
  double _outlineWidth = 2.0;
  double _outlineR = 1.0;
  double _outlineG = 0.5;
  double _outlineB = 0.0;

  // When true, outputs edges with alpha transparency instead of compositing
  // the main scene texture. Used on web where the main scene is already
  // rendered to the swapchain.
  bool _overlayOnly = false;

  // Material (owned by this class)
  final FFIMaterial _edgeMaterial;

  // Scene resources (separate from parent's scene)
  final FFIScene _edgeScene;
  final Skybox _skybox;
  final FFICamera _camera;
  final ThermionEntity _cameraEntity;

  // Fullscreen quad resources
  final FFIMaterialInstance _edgeMaterialInstance;
  final FFIVertexBuffer _quadVB;
  final FFIIndexBuffer _quadIB;
  final ThermionEntity _fullscreenQuadEntity;
  final FFITextureSampler _edgeSampler;

  // Silhouette texture to sample (mutable for resize support)
  Texture _silhouetteTexture;

  /// The silhouette texture being sampled for edge detection
  Texture get silhouetteTexture => _silhouetteTexture;

  // Main scene texture for compositing
  Texture _mainSceneTexture;
  FFITextureSampler _mainSceneSampler;

  EdgeDetectionView._(
    super.view, {
    required FFIMaterial material,
    required FFIScene scene,
    required Skybox skybox,
    required FFICamera camera,
    required ThermionEntity cameraEntity,
    required FFIMaterialInstance materialInstance,
    required FFIVertexBuffer quadVB,
    required FFIIndexBuffer quadIB,
    required ThermionEntity fullscreenQuadEntity,
    required FFITextureSampler edgeSampler,
    required Texture silhouetteTexture,
    required Texture mainSceneTexture,
    required FFITextureSampler mainSceneSampler,
  })  : _silhouetteTexture = silhouetteTexture,
        _mainSceneTexture = mainSceneTexture,
        _mainSceneSampler = mainSceneSampler,
        _edgeMaterial = material,
        _edgeScene = scene,
        _skybox = skybox,
        _camera = camera,
        _cameraEntity = cameraEntity,
        _edgeMaterialInstance = materialInstance,
        _quadVB = quadVB,
        _quadIB = quadIB,
        _fullscreenQuadEntity = fullscreenQuadEntity,
        _edgeSampler = edgeSampler;

  /// Creates and initializes a new [EdgeDetectionView].
  static Future<EdgeDetectionView> create({
    required Texture silhouetteTexture,
    required int width,
    required int height,
  }) async {
    // Create view
    final viewPtr = await withPointerCallback<TView>((cb) =>
        Engine_createViewRenderThread(FilamentApp.instance!.engine, cb));

    // Create edge material
    final materialPtr = await withPointerCallback<TMaterial>((cb) =>
        Material_createEdgeOutlineMaterialRenderThread(
            FilamentApp.instance!.engine, cb));
    final edgeMaterial = FFIMaterial(materialPtr);

    // Create scene with transparent skybox
    final edgeScene = await FilamentApp.instance!.createScene() as FFIScene;
    final skybox = await FilamentApp.instance!
        .createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 0.0);
    await edgeScene.setSkybox(skybox);

    // Create camera entity with orthographic projection
    final cameraEntity = await FilamentApp.instance!.createEntity();
    FilamentApp.instance!.transformManager.createComponent(cameraEntity);
    final camera = await FilamentApp.instance!
        .createCamera(targetEntity: cameraEntity) as FFICamera;
    await camera.setProjection(
      Projection.Orthographic,
      -1.0, 1.0, // left, right
      -1.0, 1.0, // bottom, top
      0.0, 1.0, // near, far
    );

    // Create fullscreen quad
    // Create fullscreen triangle (more efficient than quad)
    // z=0.5 to place in middle of ortho frustum (near=0, far=1)
    final positions = Float32List.fromList([
      -1.0,
      -1.0,
      0.5,
      3.0,
      -1.0,
      0.5,
      -1.0,
      3.0,
      0.5,
    ]);

    // Create vertex buffer
    final vbBuilder =
        FilamentApp.instance!.renderableManager.createVertexBufferBuilder();
    vbBuilder.vertexCount(3);
    vbBuilder.bufferCount(1);
    vbBuilder.attribute(
      VertexAttribute.POSITION,
      0,
      VertexAttributeType.FLOAT3,
      byteOffset: 0,
      byteStride: 12,
    );
    final quadVB = await vbBuilder.build() as FFIVertexBuffer;
    await quadVB.setBufferAt(0, positions);

    // Create index buffer
    final indices = Uint16List.fromList([0, 1, 2]);
    final ibBuilder =
        FilamentApp.instance!.renderableManager.createIndexBufferBuilder();
    ibBuilder.indexCount(3);
    ibBuilder.bufferType(IndexType.USHORT);
    final quadIB = await ibBuilder.build() as FFIIndexBuffer;
    await quadIB.setBuffer(indices);

    // Create edge material instance
    final edgeMaterialInstance =
        await edgeMaterial.createInstance() as FFIMaterialInstance;

    // Create texture sampler for edge detection
    final edgeSampler = await FilamentApp.instance!.createTextureSampler(
      minFilter: TextureMinFilter.NEAREST,
      magFilter: TextureMagFilter.NEAREST,
      wrapS: TextureWrapMode.CLAMP_TO_EDGE,
      wrapT: TextureWrapMode.CLAMP_TO_EDGE,
    ) as FFITextureSampler;

    // Create default 1x1 main scene texture (will be replaced when setMainSceneTexture is called)
    // This ensures the shader has a valid texture to sample before initialization completes
    final defaultMainSceneTexture = await FilamentApp.instance!.createTexture(
      1,
      1,
      flags: {TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
      textureFormat: TextureFormat.RGBA8,
    ) as FFITexture;

    final mainSceneSampler = await FilamentApp.instance!.createTextureSampler(
      minFilter: TextureMinFilter.LINEAR,
      magFilter: TextureMagFilter.LINEAR,
      wrapS: TextureWrapMode.CLAMP_TO_EDGE,
      wrapT: TextureWrapMode.CLAMP_TO_EDGE,
    ) as FFITextureSampler;

    // Create fullscreen quad entity
    final fullscreenQuadEntity = await FilamentApp.instance!.createEntity();

    final builder = FilamentApp.instance!.renderableManager.createBuilder(1);
    builder.boundingBox(Aabb3.minMax(
      Vector3(-2, -2, 0),
      Vector3(4, 4, 1),
    ));
    builder.geometry(0, PrimitiveType.TRIANGLES, quadVB, quadIB, 0, 3);
    builder.material(0, edgeMaterialInstance);
    builder.culling(false);
    builder.receiveShadows(false);
    builder.castShadows(false);
    await builder.build(fullscreenQuadEntity);

    // Add to scene
    await edgeScene.addEntity(fullscreenQuadEntity);

    // Create the EdgeDetectionView with all resources
    final edgeDetectionView = EdgeDetectionView._(
      viewPtr,
      material: edgeMaterial,
      scene: edgeScene,
      skybox: skybox,
      camera: camera,
      cameraEntity: cameraEntity,
      materialInstance: edgeMaterialInstance,
      quadVB: quadVB,
      quadIB: quadIB,
      fullscreenQuadEntity: fullscreenQuadEntity,
      edgeSampler: edgeSampler,
      silhouetteTexture: silhouetteTexture,
      mainSceneTexture: defaultMainSceneTexture,
      mainSceneSampler: mainSceneSampler,
    );

    // Configure view (renders to swap chain by default)
    await edgeDetectionView.setScene(edgeScene);
    await edgeDetectionView.setCamera(camera);
    await edgeDetectionView.setViewport(width, height);
    await edgeDetectionView.setPostProcessing(true);
    await edgeDetectionView.setShadowsEnabled(false);
    await edgeDetectionView.setFrustumCullingEnabled(false);

    await edgeDetectionView.setName("highlight_edge_detection");

    return edgeDetectionView;
  }

  @override
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      @Deprecated('Use outlineWidth instead') double scale = 1.05,
      double outlineWidth = 3.0,
      int primitiveIndex = 0}) async {
    throw Exception(
        "disableHighlightOverlay cannot be called on a highlight view");
  }

  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    throw Exception(
        "disableHighlightOverlay cannot be called on a highlight view");
  }

  @override
  Future setHighlightOverlayEnabled(bool enabled) async {
    throw UnimplementedError();
  }


  /// Set outline appearance.
  Future<void> setOutlineParams({
    double? width,
    double? r,
    double? g,
    double? b,
  }) async {
    if (width != null) _outlineWidth = width;
    if (r != null) _outlineR = r;
    if (g != null) _outlineG = g;
    if (b != null) _outlineB = b;
    await _updateEdgeMaterialParams();
  }

  /// Update the silhouette texture reference (called when SilhouetteView resizes)
  Future<void> updateSilhouetteTexture(Texture newTexture) async {
    _silhouetteTexture = newTexture;
    await _updateEdgeMaterialParams();
    _logger.info("Updated silhouette texture reference");
  }

  /// Set the main scene texture.
  ///
  /// The edge detection view samples both the silhouette and main scene
  /// textures, compositing edges on top of the scene.
  Future<void> setMainSceneTexture(Texture texture) async {
    _mainSceneTexture = texture;
    await _updateEdgeMaterialParams();
    _logger.info("Set main scene texture");
  }

  /// Enable overlay-only mode (edges with alpha, no main scene compositing).
  ///
  /// Used on web where the main scene already renders to the swapchain
  /// and the edge detection view just needs to overlay edges on top.
  Future<void> setOverlayOnly(bool value) async {
    _overlayOnly = value;
    await _updateEdgeMaterialParams();
    _logger.info("Overlay-only mode: $value");
  }

  /// Update viewport size.
  @override
  Future setViewport(int width, int height) async {
    await super.setViewport(width, height);
    await _updateEdgeMaterialParams();

    _logger.info('Viewport updated to ${width}x${height} ${getNativeHandle()}');
  }

  /// Clean up all resources.
  @override
  Future<void> destroy() async {
    // Destroy fullscreen quad
    await _edgeScene.removeEntity(_fullscreenQuadEntity);
    await FilamentApp.instance!.destroyEntity(_fullscreenQuadEntity);

    await _edgeMaterialInstance.destroy();
    await _quadVB.destroy();
    await _quadIB.destroy();

    // Destroy skybox
    await _skybox.destroy();

    // Destroy scene
    await _edgeScene.destroy();

    // Destroy camera
    await _camera.destroy();

    FilamentApp.instance!.transformManager.removeComponent(_cameraEntity);
    await FilamentApp.instance!.destroyEntity(_cameraEntity);

    // Destroy material
    await _edgeMaterial.destroy();

    // Destroy the underlying view
    await super.destroy();

    _logger.info('EdgeDetectionView disposed');
  }

  Future<void> _updateEdgeMaterialParams() async {
    final vp = await getViewport();

    // Set silhouette texture
    await _edgeMaterialInstance.setParameterTexture(
      'silhouette',
      _silhouetteTexture as FFITexture,
      _edgeSampler,
    );

    // Set main scene texture (only needed in composite mode)
    if (!_overlayOnly) {
      await _edgeMaterialInstance.setParameterTexture(
        'mainScene',
        _mainSceneTexture as FFITexture,
        _mainSceneSampler,
      );
    }

    // Set texel size (1/width, 1/height)
    await _edgeMaterialInstance.setParameterFloat2(
      'texelSize',
      1.0 / vp.width,
      1.0 / vp.height,
    );

    // Set outline color and width
    await _edgeMaterialInstance.setParameterFloat3(
      'outlineColor',
      _outlineR,
      _outlineG,
      _outlineB,
    );
    await _edgeMaterialInstance.setParameterFloat(
        'outlineWidth', _outlineWidth);

    // Set overlay-only mode
    await _edgeMaterialInstance.setParameterInt(
        'overlayOnly', _overlayOnly ? 1 : 0);
  }
}
