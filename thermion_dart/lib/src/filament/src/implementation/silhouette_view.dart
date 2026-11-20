import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Manages the first (silhouette) rendering pass for highlighted entities.
///
/// Renders highlighted entities as white silhouettes to a standalone color-only
/// render target by temporarily overriding their material instances during this
/// view's render pass.
///
/// This texture is passed to the edge detection pass.
///
class SilhouetteView {
  final _logger = Logger('SilhouetteView');

  final FFIView _view;

  /// The underlying Filament [View] for render-manager attachment and pass setup.
  View get view => _view;

  // Shared silhouette material and instance (owned by this class)
  final FFIMaterial _silhouetteMaterial;
  final FFIMaterialInstance _silhouetteMaterialInstance;

  // Render target resources (mutable for resize support)
  FFITexture _colorTexture;
  FFIRenderTarget _renderTarget;

  // Track current texture dimensions
  int _textureWidth = 0;
  int _textureHeight = 0;

  // Callback to notify when texture changes (for EdgeDetectionView)
  Future<void> Function(Texture)? onTextureResized;

  // Scene resources (separate from parent's scene, though entities are shared)
  final FFIScene _silhouetteScene;
  final Skybox _skybox;

  // Highlighted entities tracking
  final Set<ThermionEntity> _highlightedEntities = {};

  final FFIFilamentApp _app;

  SilhouetteView._(
    this._view, {
    required FFIFilamentApp app,
    required FFIMaterial material,
    required FFIMaterialInstance materialInstance,
    required FFITexture colorTexture,
    required FFIRenderTarget renderTarget,
    required FFIScene scene,
    required Skybox skybox,
  }) : _app = app,
       _silhouetteMaterial = material,
       _silhouetteMaterialInstance = materialInstance,
       _colorTexture = colorTexture,
       _renderTarget = renderTarget,
       _silhouetteScene = scene,
       _skybox = skybox;

  /// Creates and initializes a new [SilhouetteView].
  static Future<SilhouetteView> create(FFIFilamentApp app, {required int width, required int height}) async {
    final view = await FFIView.create(app) as FFIView;

    // Create silhouette material and a single shared override instance
    final silhouetteMaterial = await app.createBuiltInMaterial(BuiltInMaterial.silhouette);
    final silhouetteMaterialInstance = await silhouetteMaterial.createInstance() as FFIMaterialInstance;

    // Create color-only texture and render target (no persistent depth attachment needed;
    // Filament provides a transient depth attachment during the pass)
    final colorTexture =
        await app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.RGBA8,
            )
            as FFITexture;
    final renderTarget =
        await app.createRenderTarget(width, height, color: colorTexture, createDepth: false) as FFIRenderTarget;

    // Create scene with black skybox at highest priority (0) so it renders
    // before all silhouette geometry and clears background pixels even on a
    // color-only render target regardless of Renderer.ClearOptions.
    final silhouetteScene = await app.createScene() as FFIScene;
    final skybox = await app.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0, priority: 0);
    await silhouetteScene.setSkybox(skybox);

    // Create the SilhouetteView with all resources
    final silhouetteView = SilhouetteView._(
      view,
      app: app,
      material: silhouetteMaterial,
      materialInstance: silhouetteMaterialInstance,
      colorTexture: colorTexture,
      renderTarget: renderTarget,
      scene: silhouetteScene,
      skybox: skybox,
    );

    // Initialize texture dimensions to prevent resize on first setViewport
    silhouetteView._textureWidth = width;
    silhouetteView._textureHeight = height;

    // Configure this view
    await view.setScene(silhouetteScene);
    await silhouetteView.setViewport(width, height);
    await view.setRenderTarget(renderTarget);
    await view.setPostProcessing(false);
    await view.setShadowsEnabled(false);

    // Register native per-view material override so shared entities render with
    // the double-sided opaque silhouette material without duplicating geometry.
    await view.setMaterialOverride(silhouetteMaterialInstance);

    await view.setName("highlight_silhouette");

    return silhouetteView;
  }

  Future<void> setCamera(Camera? camera) => _view.setCamera(camera);

  Future<void> setViewport(int width, int height) async {
    _logger.info("setViewport $width x $height (current texture: ${_textureWidth}x${_textureHeight})");
    await _view.setViewport(width, height);

    // Resize if dimensions are valid and different from current texture size
    if (width > 0 && height > 0 && (width != _textureWidth || height != _textureHeight)) {
      await _resizeRenderTarget(width, height);
    }
  }

  Future _resizeRenderTarget(int width, int height) async {
    _logger.info("Resizing render target from ${_textureWidth}x${_textureHeight} to ${width}x${height}");

    // Store old resources for cleanup
    final oldColorTexture = _colorTexture;
    final oldRenderTarget = _renderTarget;

    // Create new color texture and color-only render target
    _colorTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.RGBA8,
            )
            as FFITexture;

    _renderTarget =
        await _app.createRenderTarget(width, height, color: _colorTexture, createDepth: false) as FFIRenderTarget;

    // Set new render target on view
    await _view.setRenderTarget(_renderTarget);

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

    _logger.info("Render target resized successfully");
  }

  /// The color texture containing white silhouettes (for edge detection sampling).
  Texture get colorTexture => _colorTexture;

  /// Add a highlight for the given entity by sharing it in [_silhouetteScene].
  Future<void> addHighlight({required ThermionEntity target}) async {
    if (_highlightedEntities.contains(target)) return;

    if (!_app.renderableManager.hasComponent(target)) {
      _logger.warning('Entity $target is not renderable');
      return;
    }

    await _silhouetteScene.addEntity(target);
    _highlightedEntities.add(target);

    _logger.info('Added silhouette for entity $target');
  }

  /// Remove highlight from an entity.
  Future<void> removeHighlight(ThermionEntity target) async {
    if (!_highlightedEntities.remove(target)) return;

    await _silhouetteScene.removeEntity(target);

    _logger.info('Removed silhouette for entity $target');
  }

  /// Clean up all resources.
  Future<void> destroy() async {
    // Remove all highlights from the silhouette scene
    for (final target in _highlightedEntities.toList()) {
      await removeHighlight(target);
    }

    // Clear the native override before destroying the material instance/view
    await _view.setMaterialOverride(null);

    // Destroy skybox
    await _skybox.destroy();

    // Destroy scene
    await _silhouetteScene.destroy();

    // Destroy render target and color texture
    await _renderTarget.destroy();
    await _colorTexture.dispose();

    // Destroy material instance and material
    await _silhouetteMaterialInstance.destroy();
    await _silhouetteMaterial.destroy();

    // Destroy the underlying view
    await _view.destroy();

    _logger.info('SilhouetteView disposed');
  }
}
