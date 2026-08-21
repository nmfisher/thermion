import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Component data for highlighted entities
class _SilhouetteComponent {
  final MaterialInstance silhouetteMaterialInstance;
  final ThermionEntity silhouetteEntity;

  _SilhouetteComponent({required this.silhouetteMaterialInstance, required this.silhouetteEntity});
}

/// Manages the first (silhouette) rendering pass for highlighted entities.
///
/// Renders highlighted entities as white silhouettes to a standalone texture/render target.
///
/// This texture is passed to the edge detection pass.
///
class SilhouetteView extends FFIView {
  final _logger = Logger('SilhouetteView');

  // Material (owned by this class)
  final FFIMaterial _silhouetteMaterial;

  // Render target resources (mutable for resize support)
  FFITexture _colorTexture;
  FFITexture _depthTexture;
  FFIRenderTarget _renderTarget;

  // Track current texture dimensions
  int _textureWidth = 0;
  int _textureHeight = 0;

  // Callback to notify when texture changes (for EdgeDetectionView)
  Future<void> Function(Texture)? onTextureResized;

  // Scene resources (separate from parent's scene)
  final FFIScene _silhouetteScene;
  final Skybox _skybox;

  // Highlighted entities tracking
  final Map<ThermionEntity, _SilhouetteComponent> _components = {};

  final FFIFilamentApp _app;

  SilhouetteView._(
    Pointer<TView> view, {
    required FFIFilamentApp app,
    required FFIMaterial material,
    required FFITexture colorTexture,
    required FFITexture depthTexture,
    required FFIRenderTarget renderTarget,
    required FFIScene scene,
    required Skybox skybox,
  }) : _app = app,
       _silhouetteMaterial = material,
       _colorTexture = colorTexture,
       _depthTexture = depthTexture,
       _renderTarget = renderTarget,
       _silhouetteScene = scene,
       _skybox = skybox,
       super(view, app);

  /// Creates and initializes a new [SilhouetteView].
  static Future<SilhouetteView> create(FFIFilamentApp app, {required int width, required int height}) async {
    final viewPtr = await withPointerCallback<TView>((cb) => Engine_createViewRenderThread(app.engine, cb));

    // Create silhouette material
    final materialPtr = await withPointerCallback<TMaterial>(
      (cb) => Material_createSilhouetteMaterialRenderThread(app.engine, cb),
    );
    final silhouetteMaterial = FFIMaterial(materialPtr, app);

    // Create textures and render target
    final colorTexture =
        await app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.RGBA8,
            )
            as FFITexture;
    final depthTexture =
        await app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT},
              textureFormat: TextureFormat.DEPTH32F,
            )
            as FFITexture;
    final renderTarget =
        await app.createRenderTarget(width, height, color: colorTexture, depth: depthTexture) as FFIRenderTarget;

    // Create scene with black skybox to clear render target
    final silhouetteScene = await app.createScene() as FFIScene;
    final skybox = await app.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
    await silhouetteScene.setSkybox(skybox);

    // Create the SilhouetteView with all resources
    final silhouetteView = SilhouetteView._(
      viewPtr,
      app: app,
      material: silhouetteMaterial,
      colorTexture: colorTexture,
      depthTexture: depthTexture,
      renderTarget: renderTarget,
      scene: silhouetteScene,
      skybox: skybox,
    );

    // Initialize texture dimensions to prevent resize on first setViewport
    silhouetteView._textureWidth = width;
    silhouetteView._textureHeight = height;

    // Configure this view
    await silhouetteView.setScene(silhouetteScene);
    await silhouetteView.setViewport(width, height);
    await silhouetteView.setRenderTarget(renderTarget);
    await silhouetteView.setPostProcessing(false);
    await silhouetteView.setShadowsEnabled(false);

    await silhouetteView.setName("highlight_silhouette");

    return silhouetteView;
  }

  @override
  Future setViewport(int width, int height) async {
    _logger.info("setViewport $width x $height (current texture: ${_textureWidth}x${_textureHeight})");
    await super.setViewport(width, height);

    // Resize if dimensions are valid and different from current texture size
    if (width > 0 && height > 0 && (width != _textureWidth || height != _textureHeight)) {
      await _resizeRenderTarget(width, height);
    }
  }

  Future _resizeRenderTarget(int width, int height) async {
    _logger.info("Resizing render target from ${_textureWidth}x${_textureHeight} to ${width}x${height}");

    // Store old resources for cleanup
    final oldColorTexture = _colorTexture;
    final oldDepthTexture = _depthTexture;
    final oldRenderTarget = _renderTarget;

    // Create new textures
    _colorTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.RGBA8,
            )
            as FFITexture;

    _depthTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT},
              textureFormat: TextureFormat.DEPTH32F,
            )
            as FFITexture;

    _renderTarget =
        await _app.createRenderTarget(width, height, color: _colorTexture, depth: _depthTexture) as FFIRenderTarget;

    // Set new render target on view
    await setRenderTarget(_renderTarget);

    // Update tracked dimensions
    _textureWidth = width;
    _textureHeight = height;

    // Notify listeners (EdgeDetectionView needs new texture reference)
    await onTextureResized?.call(_colorTexture);

    // Flush render thread to ensure new textures are bound before destroying old ones
    // This prevents "Invalid texture still bound to MaterialInstance" errors
    await _app.flush();

    // Destroy old resources
    await oldRenderTarget.destroy();
    await oldColorTexture.dispose();
    await oldDepthTexture.dispose();

    _logger.info("Render target resized successfully");
  }

  /// The color texture containing white silhouettes (for edge detection sampling).
  Texture get colorTexture => _colorTexture;

  Future<bool> enableHighlightOverlay() async => throw Exception();

  Future disableHighlightOverlay() async => throw Exception();

  @override
  Future setStencilHighlight(
    ThermionAsset asset, {
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? entity,
    @Deprecated('Use outlineWidth instead') double scale = 1.05,
    double outlineWidth = 3.0,
    int primitiveIndex = 0,
    ThermionAsset? geometrySource,
  }) async {
    // No-op for overlay views
  }

  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    throw Exception();
  }

  /// Add a highlight for the given entity.
  Future<void> addHighlight({
    required ThermionEntity target,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
    required int indexCount,
  }) async {
    if (_components.containsKey(target)) return;

    if (!_app.renderableManager.hasComponent(target)) {
      _logger.warning('Entity $target is not renderable');
      return;
    }

    // Create silhouette material instance
    final silhouetteMi = await _silhouetteMaterial.createInstance();

    // Create silhouette entity
    final silhouetteEntity = await _app.createEntity();

    // Get original bounding box
    final boundingBox = _app.renderableManager.getAxisAlignedBoundingBox(target);

    // Build silhouette renderable
    final builder = _app.renderableManager.createBuilder(1);
    builder.boundingBox(boundingBox);
    builder.geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, indexCount);
    builder.material(0, silhouetteMi);
    builder.culling(true);
    builder.receiveShadows(false);
    builder.castShadows(false);
    await builder.build(silhouetteEntity);

    // Parent silhouette entity to target so it follows transforms
    _app.transformManager.setParent(silhouetteEntity, target);

    // Add to silhouette scene
    await _silhouetteScene.addEntity(silhouetteEntity);

    // Store component
    _components[target] = _SilhouetteComponent(
      silhouetteMaterialInstance: silhouetteMi,
      silhouetteEntity: silhouetteEntity,
    );

    _logger.info('Added silhouette for entity $target');
  }

  /// Remove highlight from an entity.
  Future<void> removeHighlight(ThermionEntity target) async {
    final component = _components.remove(target);
    if (component == null) return;

    // Remove from scene
    await _silhouetteScene.removeEntity(component.silhouetteEntity);

    // Destroy entity
    await _app.destroyEntity(component.silhouetteEntity);

    // Destroy material instance
    await component.silhouetteMaterialInstance.destroy();

    _logger.info('Removed silhouette for entity $target');
  }

  /// Clean up all resources.
  @override
  Future<void> destroy() async {
    // Remove all highlights
    for (final target in _components.keys.toList()) {
      await removeHighlight(target);
    }

    // Destroy skybox
    await _skybox.destroy();

    // Destroy scene
    await _silhouetteScene.destroy();

    // Destroy render target and textures
    await _renderTarget.destroy();
    await _colorTexture.dispose();
    await _depthTexture.dispose();

    // Destroy material
    await _silhouetteMaterial.destroy();

    // Destroy the underlying view
    await super.destroy();

    _logger.info('SilhouetteView disposed');
  }
}
