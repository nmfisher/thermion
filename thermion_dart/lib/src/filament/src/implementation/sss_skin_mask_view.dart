import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

class _SkinMaskComponent {
  final MaterialInstance materialInstance;
  final ThermionEntity entity;

  _SkinMaskComponent({required this.materialInstance, required this.entity});
}

/// Renders the assets marked as skin as solid white into its own render target.
///
/// The result is the coverage mask the subsurface scattering passes use to keep
/// the scatter off the rest of the scene.
///
/// Filament only allows custom MRT outputs on UNLIT surface materials, and its
/// LIT materials offer no "is skin" output, so coverage cannot be captured from
/// the main pass. Rendering the skin again with the existing opaque white
/// [SilhouetteView]-style material is the cheapest alternative: the geometry is
/// re-submitted, but no fragment work beyond a constant colour write happens.
///
/// Only the skin assets are in this view's scene, so skin occluded by other
/// geometry is still marked as covered. The depth-aware blur and the mask
/// itself contain that to the skin's own pixels; see the design doc for the
/// detail.
class SssSkinMaskView extends FFIView {
  final _logger = Logger('SssSkinMaskView');

  // Material (owned by this class). Reuses the existing embedded white unlit
  // material so no extra shader package is needed for the mask.
  final FFIMaterial _maskMaterial;

  FFITexture _colorTexture;
  FFITexture _depthTexture;
  FFIRenderTarget _renderTarget;

  int _textureWidth = 0;
  int _textureHeight = 0;

  /// Notified when the mask texture is recreated, so the passes that sample it
  /// can rebind (same pattern as [SilhouetteView.onTextureResized]).
  Future<void> Function(Texture)? onMaskTextureResized;

  final FFIScene _maskScene;
  final Skybox _skybox;

  final Map<ThermionEntity, List<_SkinMaskComponent>> _components = {};

  /// The entities currently contributing to the mask.
  Set<ThermionEntity> get skinEntities => Set.unmodifiable(_components.keys);

  final FFIFilamentApp _app;

  SssSkinMaskView._(
    Pointer<TView> view, {
    required FFIFilamentApp app,
    required FFIMaterial material,
    required FFITexture colorTexture,
    required FFITexture depthTexture,
    required FFIRenderTarget renderTarget,
    required FFIScene scene,
    required Skybox skybox,
  }) : _app = app,
       _maskMaterial = material,
       _colorTexture = colorTexture,
       _depthTexture = depthTexture,
       _renderTarget = renderTarget,
       _maskScene = scene,
       _skybox = skybox,
       super(view, app);

  static Future<SssSkinMaskView> create(FFIFilamentApp app, {required int width, required int height}) async {
    final viewPtr = await withPointerCallback<TView>((cb) => Engine_createViewRenderThread(app.engine, cb));

    final materialPtr = await withPointerCallback<TMaterial>(
      (cb) => Material_createSilhouetteMaterialRenderThread(app.engine, cb),
    );
    final material = FFIMaterial(materialPtr, app);

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

    final scene = await app.createScene() as FFIScene;
    // Black clear: anything the skin does not cover must read as "not skin".
    final skybox = await app.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
    await scene.setSkybox(skybox);

    final maskView = SssSkinMaskView._(
      viewPtr,
      app: app,
      material: material,
      colorTexture: colorTexture,
      depthTexture: depthTexture,
      renderTarget: renderTarget,
      scene: scene,
      skybox: skybox,
    );

    maskView._textureWidth = width;
    maskView._textureHeight = height;

    await maskView.setScene(scene);
    await maskView.setViewport(width, height);
    await maskView.setRenderTarget(renderTarget);
    await maskView.setPostProcessing(false);
    await maskView.setShadowsEnabled(false);
    await maskView.setName("sss_skin_mask");

    return maskView;
  }

  /// The coverage mask, 1 where a skin asset was rendered.
  Texture get maskTexture => _colorTexture;

  @override
  Future setViewport(int width, int height) async {
    await super.setViewport(width, height);

    if (width > 0 && height > 0 && (width != _textureWidth || height != _textureHeight)) {
      await _resizeRenderTarget(width, height);
    }
  }

  Future<void> _resizeRenderTarget(int width, int height) async {
    _logger.info("Resizing skin mask render target ${_textureWidth}x$_textureHeight -> ${width}x$height");

    final oldColorTexture = _colorTexture;
    final oldDepthTexture = _depthTexture;
    final oldRenderTarget = _renderTarget;

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

    await setRenderTarget(_renderTarget);

    _textureWidth = width;
    _textureHeight = height;

    // Rebind on every material instance that still points at the old texture,
    // then flush so the render thread has released the old one before it is
    // destroyed.
    await onMaskTextureResized?.call(_colorTexture);
    await _app.flush();

    await oldRenderTarget.destroy();
    await oldColorTexture.dispose();
    await oldDepthTexture.dispose();
  }

  /// Marks [asset] as skin.
  ///
  /// Reuses the asset's vertex and index buffers, so the asset must have been
  /// loaded with `accessibleGeometryBuffers`, exactly as for
  /// [FFIView.setStencilHighlight].
  /// Adds one primitive of a skin entity to the mask.
  ///
  /// An entity with several primitives calls this once per primitive; the
  /// first call also registers the entity.
  Future<void> addSkin({
    required ThermionEntity target,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
    required int indexCount,
  }) async {
    if (!_app.renderableManager.hasComponent(target)) {
      _logger.warning('Entity $target is not renderable; not adding to the skin mask');
      return;
    }

    final materialInstance = await _maskMaterial.createInstance();

    final entity = await _app.createEntity();

    final boundingBox = _app.renderableManager.getAxisAlignedBoundingBox(target);

    final builder = _app.renderableManager.createBuilder(1);
    builder.boundingBox(boundingBox);
    builder.geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, indexCount);
    builder.material(0, materialInstance);
    builder.culling(true);
    builder.receiveShadows(false);
    builder.castShadows(false);
    await builder.build(entity);

    _app.transformManager.setParent(entity, target);

    await _maskScene.addEntity(entity);

    _components
        .putIfAbsent(target, () => [])
        .add(_SkinMaskComponent(materialInstance: materialInstance, entity: entity));
  }

  /// Removes every primitive previously added for [target].
  Future<void> removeSkin(ThermionEntity target) async {
    final components = _components.remove(target);
    if (components == null) return;

    for (final component in components) {
      await _maskScene.removeEntity(component.entity);
      await _app.destroyEntity(component.entity);
      await component.materialInstance.destroy();
    }
  }

  @override
  Future setStencilHighlight(
    ThermionAsset asset, {
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? entity,
    double scale = 1.05,
    double outlineWidth = 3.0,
    int primitiveIndex = 0,
    ThermionAsset? geometrySource,
  }) {
    throw UnsupportedError("Not supported for the skin mask view");
  }

  @override
  Future removeStencilHighlight(ThermionAsset asset) {
    throw UnsupportedError("Not supported for the skin mask view");
  }

  @override
  Future<void> destroy() async {
    for (final target in _components.keys.toList()) {
      await removeSkin(target);
    }

    await _skybox.destroy();
    await _maskScene.destroy();

    await _renderTarget.destroy();
    await _colorTexture.dispose();
    await _depthTexture.dispose();

    await _maskMaterial.destroy();

    await super.destroy();

    _logger.info('SssSkinMaskView disposed');
  }
}
