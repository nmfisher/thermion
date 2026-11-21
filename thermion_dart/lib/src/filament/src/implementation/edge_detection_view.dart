import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_color_grading.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Manages the edge detection pass for outline rendering.
///
/// Renders a fullscreen quad that samples the silhouette texture and
/// draws outlines where edges are detected.
///
class EdgeDetectionView {
  final _logger = Logger('EdgeDetectionView');

  final FFIView _view;

  /// The underlying Filament [View] for render-manager attachment and pass setup.
  View get view => _view;

  // Outline settings
  double _outlineWidth = 2.0;
  double _outlineR = 1.0;
  double _outlineG = 0.5;
  double _outlineB = 0.0;

  // Material (owned by this class)
  final FFIMaterial _edgeMaterial;

  // Scene resources (separate from parent's scene)
  final Scene _edgeScene;
  final Skybox _skybox;
  final Camera _camera;

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

  // Linear color grading to avoid double tone-mapping (owned by this class)
  final ColorGrading _linearColorGrading;
  final ToneMapper _linearToneMapper;

  final FFIFilamentApp _app;

  EdgeDetectionView._(
    this._view, {
    required FFIFilamentApp app,
    required FFIMaterial material,
    required Scene scene,
    required Skybox skybox,
    required Camera camera,
    required FFIMaterialInstance materialInstance,
    required FFIVertexBuffer quadVB,
    required FFIIndexBuffer quadIB,
    required ThermionEntity fullscreenQuadEntity,
    required FFITextureSampler edgeSampler,
    required Texture silhouetteTexture,
    required ColorGrading linearColorGrading,
    required ToneMapper linearToneMapper,
  }) : _app = app,
       _silhouetteTexture = silhouetteTexture,
       _edgeMaterial = material,
       _edgeScene = scene,
       _skybox = skybox,
       _camera = camera,
       _edgeMaterialInstance = materialInstance,
       _quadVB = quadVB,
       _quadIB = quadIB,
       _fullscreenQuadEntity = fullscreenQuadEntity,
       _edgeSampler = edgeSampler,
       _linearColorGrading = linearColorGrading,
       _linearToneMapper = linearToneMapper;

  /// Creates and initializes a new [EdgeDetectionView].
  static Future<EdgeDetectionView> create(
    FFIFilamentApp app, {
    required Texture silhouetteTexture,
    required int width,
    required int height,
  }) async {
    final view = await FFIView.create(app) as FFIView;

    // Create edge material
    final edgeMaterial = await app.createBuiltInMaterial(BuiltInMaterial.edgeOutline);

    // Create scene with transparent skybox
    final edgeScene = await app.createScene();
    final skybox = await app.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 0.0);
    await edgeScene.setSkybox(skybox);

    // Create camera entity with orthographic projection
    final camera = await app.createCamera();
    await camera.setProjection(
      Projection.Orthographic,
      -1.0,
      1.0, // left, right
      -1.0,
      1.0, // bottom, top
      0.0,
      1.0, // near, far
    );

    // Create fullscreen quad
    // Create fullscreen triangle (more efficient than quad)
    // z=0.5 to place in middle of ortho frustum (near=0, far=1)
    final positions = Float32List.fromList([-1.0, -1.0, 0.5, 3.0, -1.0, 0.5, -1.0, 3.0, 0.5]);

    // Create vertex buffer
    final vbBuilder = app.renderableManager.createVertexBufferBuilder();
    vbBuilder.vertexCount(3);
    vbBuilder.bufferCount(1);
    vbBuilder.attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3, byteOffset: 0, byteStride: 12);
    final quadVB = await vbBuilder.build() as FFIVertexBuffer;
    await quadVB.setBufferAt(0, positions);

    // Create index buffer
    final indices = Uint16List.fromList([0, 1, 2]);
    final ibBuilder = app.renderableManager.createIndexBufferBuilder();
    ibBuilder.indexCount(3);
    ibBuilder.bufferType(IndexType.USHORT);
    final quadIB = await ibBuilder.build() as FFIIndexBuffer;
    await quadIB.setBuffer(indices);

    // Create edge material instance
    final edgeMaterialInstance = await edgeMaterial.createInstance() as FFIMaterialInstance;

    // Create texture sampler for edge detection
    final edgeSampler =
        await app.createTextureSampler(
              minFilter: TextureMinFilter.NEAREST,
              magFilter: TextureMagFilter.NEAREST,
              wrapS: TextureWrapMode.CLAMP_TO_EDGE,
              wrapT: TextureWrapMode.CLAMP_TO_EDGE,
            )
            as FFITextureSampler;

    // Create fullscreen quad entity
    final fullscreenQuadEntity = await app.createEntity();

    final builder = app.renderableManager.createBuilder(1);
    builder.boundingBox(Aabb3.minMax(Vector3(-2, -2, 0), Vector3(4, 4, 1)));
    builder.geometry(0, PrimitiveType.TRIANGLES, quadVB, quadIB, 0, 3);
    builder.material(0, edgeMaterialInstance);
    builder.culling(false);
    builder.receiveShadows(false);
    builder.castShadows(false);
    await builder.build(fullscreenQuadEntity);

    // Add to scene
    await edgeScene.addEntity(fullscreenQuadEntity);

    // Create linear tone mapper and color grading to avoid double tone-mapping.
    // In composite mode, the main scene texture is already tone-mapped, so we
    // use a pass-through (linear) tone mapper to preserve colors while still
    // benefiting from other post-processing effects (anti-aliasing, dithering).
    final linearToneMapper = await ToneMapper.linear(app);
    final colorGradingBuilder = FFIColorGradingBuilder(
      await withPointerCallback<TColorGradingBuilder>(
        (cb) => ColorGradingBuilder_createJobThread(app.jobThreadHandle, cb),
      ),
      app,
    );
    colorGradingBuilder.toneMapper(linearToneMapper);
    final linearColorGrading = await colorGradingBuilder.build();
    await colorGradingBuilder.dispose();

    // Create the EdgeDetectionView with all resources
    final edgeDetectionView = EdgeDetectionView._(
      view,
      app: app,
      material: edgeMaterial,
      scene: edgeScene,
      skybox: skybox,
      camera: camera,
      materialInstance: edgeMaterialInstance,
      quadVB: quadVB,
      quadIB: quadIB,
      fullscreenQuadEntity: fullscreenQuadEntity,
      edgeSampler: edgeSampler,
      silhouetteTexture: silhouetteTexture,
      linearColorGrading: linearColorGrading,
      linearToneMapper: linearToneMapper,
    );

    // Configure view (renders to swap chain by default)
    await view.setScene(edgeScene);
    await view.setCamera(camera);
    await edgeDetectionView.setViewport(width, height);

    // Disable post-processing entirely: the main view already ran its own
    // tone-mapping/post-processing into the target, and the edge shader writes
    // premultiplied alpha directly onto it.
    await view.setPostProcessing(false);

    await view.setShadowsEnabled(false);
    await view.setFrustumCullingEnabled(false);

    await view.setName("highlight_edge_detection");

    return edgeDetectionView;
  }

  Future<void> setRenderTarget(RenderTarget? renderTarget) => _view.setRenderTarget(renderTarget);

  /// Set outline appearance.
  Future<void> setOutlineParams({double? width, double? r, double? g, double? b}) async {
    if (width != null) _outlineWidth = width;
    if (r != null) _outlineR = r;
    if (g != null) _outlineG = g;
    if (b != null) _outlineB = b;
    await _updateEdgeMaterialParams();
  }

  /// Update the silhouette texture reference (called when
  /// SilhouetteView resizes)
  Future<void> updateSilhouetteTexture(Texture newTexture) async {
    _silhouetteTexture = newTexture;
    await _updateEdgeMaterialParams();
    _logger.info("Updated silhouette texture reference");
  }

  /// Update viewport size.
  Future<void> setViewport(int width, int height) async {
    await _view.setViewport(width, height);
    await _updateEdgeMaterialParams();

    _logger.info('Viewport updated to ${width}x${height} ${_view.getNativeHandle()}');
  }

  /// Clean up all resources.
  Future<void> destroy() async {
    await _view.setRenderTarget(null);
    await _view.setCamera(null);

    View_setScene(_view.getNativeHandle(), nullptr);

    // Destroy fullscreen quad
    await _edgeScene.removeEntity(_fullscreenQuadEntity);
    await _app.destroyEntity(_fullscreenQuadEntity);

    await _edgeMaterialInstance.destroy();
    await _quadVB.destroy();
    await _quadIB.destroy();

    await _edgeScene.setSkybox(null);

    // Destroy skybox
    await _skybox.destroy();

    // Destroy scene
    await (_edgeScene as FFIScene).destroy();

    // Destroy material
    await _edgeMaterial.destroy();

    // Clear color grading before destroying (must be done before
    // view destruction)
    await _view.setColorGrading(null);
    await (_linearColorGrading as FFIColorGrading).dispose();
    await _linearToneMapper.dispose();

    // Destroy camera
    await _camera.destroy();

    // Destroy the underlying view
    await _view.destroy();

    _logger.info('EdgeDetectionView disposed');
  }

  Future<void> _updateEdgeMaterialParams() async {
    final vp = await _view.getViewport();

    // Set silhouette texture
    await _edgeMaterialInstance.setParameterTexture('silhouette', _silhouetteTexture as FFITexture, _edgeSampler);

    // Set texel size (1/width, 1/height)
    await _edgeMaterialInstance.setParameterFloat2('texelSize', 1.0 / vp.width, 1.0 / vp.height);

    // Set outline color and width
    await _edgeMaterialInstance.setParameterFloat3('outlineColor', _outlineR, _outlineG, _outlineB);
    await _edgeMaterialInstance.setParameterFloat('outlineWidth', _outlineWidth);
  }
}
