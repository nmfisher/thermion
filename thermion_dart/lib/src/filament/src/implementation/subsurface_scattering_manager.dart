import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/sss_fullscreen_pass_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/sss_skin_mask_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Tunables for the screen-space subsurface scattering pass.
///
/// All values are settable at any time; they are pushed to the material
/// instances on the next [SubsurfaceScatteringManager._updateParameters].
class SubsurfaceScatteringParameters {
  /// Scatter radius in full-resolution screen pixels, per colour channel.
  ///
  /// Red scatters furthest in skin, blue least; this chromatic split is the
  /// main visual cue of the effect.
  double radiusRed;
  double radiusGreen;
  double radiusBlue;

  /// How aggressively samples are rejected for being at a different depth.
  ///
  /// Larger values keep the scatter tighter to the surface and stop colour
  /// bleeding across silhouettes; smaller values let it spread across depth
  /// discontinuities. Units are inverse view-space distance, so this is
  /// scene-scale dependent.
  double depthFalloff;

  /// Linear blend factor between the un-scattered and the scattered colour,
  /// 0 = no effect, 1 = full scatter.
  double intensity;

  /// Resolution of the blur passes relative to the main view, 0.5 = half.
  ///
  /// Must be in (0, 1]. Lower is cheaper and softer.
  double blurResolutionScale;

  /// Set false to ignore the depth buffer entirely.
  bool depthAware;

  /// Set false to scatter the whole frame instead of only the skin assets.
  bool maskAware;

  SubsurfaceScatteringParameters({
    this.radiusRed = 12.0,
    this.radiusGreen = 7.0,
    this.radiusBlue = 4.0,
    this.depthFalloff = 25.0,
    this.intensity = 0.9,
    this.blurResolutionScale = 0.5,
    this.depthAware = true,
    this.maskAware = true,
  });

  SubsurfaceScatteringParameters copy() => SubsurfaceScatteringParameters(
    radiusRed: radiusRed,
    radiusGreen: radiusGreen,
    radiusBlue: radiusBlue,
    depthFalloff: depthFalloff,
    intensity: intensity,
    blurResolutionScale: blurResolutionScale,
    depthAware: depthAware,
    maskAware: maskAware,
  );
}

/// Screen-space subsurface scattering for skin, built out of fullscreen-quad
/// passes.
///
/// Filament has no public post-process hook and no engine-side subsurface
/// diffusion (see docs/screen-space-subsurface-scattering.md), so this is
/// implemented as ordinary [View]s that the RenderManager submits in a fixed
/// order each frame:
///
/// | order | view                | renders to                        |
/// |-------|---------------------|-----------------------------------|
/// | 0     | skin mask           | mask render target (full res)     |
/// | 1     | the main view       | scene colour + depth (full res)   |
/// | 2     | horizontal blur     | scatter buffer A (reduced res)    |
/// | 3     | vertical blur       | scatter buffer B (reduced res)    |
/// | 4     | composite           | the main view's original target   |
///
/// Enabling this takes ownership of the main view's render target: the view is
/// redirected into an internal colour/depth pair so the passes have something
/// to sample. It therefore cannot be combined with the highlight overlay,
/// which wants the same thing; [enable] throws if that is already on.
///
/// Five views are attached to the swapchain and Filament's RenderManager takes
/// at most eight, so at most three remain for other overlays.
class SubsurfaceScatteringManager {
  final _logger = Logger('SubsurfaceScatteringManager');

  final FFIFilamentApp _app;
  final SssSkinMaskView maskView;
  final SssBlurView horizontalBlurView;
  final SssBlurView verticalBlurView;
  final SssCompositeView compositeView;

  SubsurfaceScatteringParameters parameters = SubsurfaceScatteringParameters();

  View? _mainView;
  Camera? _camera;
  RenderTarget? _originalMainViewRenderTarget;
  RenderTarget? _outputRenderTarget;

  FFITexture? _sceneColorTexture;
  FFITexture? _sceneDepthTexture;
  FFIRenderTarget? _sceneRenderTarget;
  int _sceneWidth = 0;
  int _sceneHeight = 0;

  FFITexture? _scatterATexture;
  FFITexture? _scatterBTexture;
  FFITexture? _scatterADepthTexture;
  FFITexture? _scatterBDepthTexture;
  FFIRenderTarget? _scatterARenderTarget;
  FFIRenderTarget? _scatterBRenderTarget;
  int _scatterWidth = 0;
  int _scatterHeight = 0;

  SubsurfaceScatteringManager._({
    required FFIFilamentApp app,
    required this.maskView,
    required this.horizontalBlurView,
    required this.verticalBlurView,
    required this.compositeView,
  }) : _app = app;

  static Future<SubsurfaceScatteringManager> create(
    FFIFilamentApp app, {
    required int width,
    required int height,
  }) async {
    final maskView = await SssSkinMaskView.create(app, width: width, height: height);
    // The blur passes run at reduced resolution, so their views are sized for
    // the scatter buffers rather than for the main view.
    final (scatterWidth, scatterHeight) = _scatterSize(
      width,
      height,
      SubsurfaceScatteringParameters().blurResolutionScale,
    );
    final horizontalBlurView = await SssBlurView.create(app, width: scatterWidth, height: scatterHeight);
    final verticalBlurView = await SssBlurView.create(app, width: scatterWidth, height: scatterHeight);
    final compositeView = await SssCompositeView.create(app, width: width, height: height);

    final manager = SubsurfaceScatteringManager._(
      app: app,
      maskView: maskView,
      horizontalBlurView: horizontalBlurView,
      verticalBlurView: verticalBlurView,
      compositeView: compositeView,
    );

    maskView.onMaskTextureResized = (texture) => manager._updateParameters();

    return manager;
  }

  /// The entities currently contributing to the skin mask.
  Set<ThermionEntity> get skinEntities => maskView.skinEntities;

  /// Marks every primitive of [asset] as skin.
  ///
  /// The mask pass reuses the asset's vertex and index buffers, so the asset
  /// must have been loaded with `accessibleGeometryBuffers` — the same
  /// requirement as `View.setStencilHighlight`. [geometrySource] supplies the
  /// buffers when the entity itself does not carry them (e.g. instanced
  /// assets whose root holds the preserved geometry).
  Future<void> addSkin(ThermionAsset asset, {ThermionAsset? geometrySource}) async {
    final geoAsset = (geometrySource ?? asset) as FFIAsset;
    if (!geoAsset.geometryCapabilities.contains(SceneAssetGeometryCapability.accessibleGeometryBuffers)) {
      throw StateError(
        "addSkin requires accessible geometry buffers. Load the asset with "
        "requiredGeometryCapabilities containing accessibleGeometryBuffers.",
      );
    }

    final entities = [asset.entity, ...await asset.getChildEntities()];
    for (final entity in entities) {
      final offset = await geoAsset.getPrimitiveOffsetForEntity(entity);
      if (offset < 0) {
        _logger.warning("addSkin: no accessible geometry buffers for entity $entity; skipping");
        continue;
      }

      final primCount = await _app.getPrimitiveCount(entity);
      for (int i = 0; i < primCount; i++) {
        final flatPrimIndex = offset + i;
        final vertexBuffer = geoAsset.getVertexBuffer(primitiveIndex: flatPrimIndex);
        final indexBuffer = SceneAsset_getIndexBuffer(geoAsset.asset, flatPrimIndex);

        if (vertexBuffer == null || indexBuffer == nullptr) {
          continue;
        }
        if (vertexBuffer is! FFIVertexBuffer) {
          _logger.warning("addSkin: unexpected vertex buffer type for entity $entity primitive $i");
          continue;
        }

        await maskView.addSkin(
          target: entity,
          vertexBuffer: vertexBuffer,
          indexBuffer: FFIIndexBuffer(indexBuffer, _app.engine),
          indexCount: IndexBuffer_getIndexCount(indexBuffer),
        );
      }
    }

    await _updateParameters();
  }

  /// Stops marking [asset] as skin.
  Future<void> removeSkin(ThermionAsset asset) async {
    final entities = [asset.entity, ...await asset.getChildEntities()];
    for (final entity in entities) {
      await maskView.removeSkin(entity);
    }
    await _updateParameters();
  }

  /// Wires the pass views into [swapChain]'s render order and redirects
  /// [mainView] into the internal scene render target.
  ///
  /// [outputRenderTarget] is where the composite pass writes — the render
  /// target the main view was rendering into before it was redirected. When it
  /// is null the composite pass writes to [swapChain] directly.
  Future<void> enable(View mainView, SwapChain swapChain, {RenderTarget? outputRenderTarget}) async {
    if (mainView.getHighlightOverlay() != null) {
      throw StateError(
        "Subsurface scattering cannot be enabled while the highlight overlay is "
        "enabled on this view: both need to redirect the main view into their "
        "own render target. Disable the highlight overlay first.",
      );
    }

    _mainView = mainView;
    _originalMainViewRenderTarget = await mainView.getRenderTarget();
    _outputRenderTarget = outputRenderTarget ?? _originalMainViewRenderTarget;

    final vp = await mainView.getViewport();
    final width = vp.width > 0 ? vp.width : 1;
    final height = vp.height > 0 ? vp.height : 1;

    // The mask pass renders the skin in world space, so it has to see the
    // scene through the same camera as the main view or the mask would not line
    // up with the pixels it is gating. Sharing the Camera component is what the
    // highlight overlay does too.
    await setCamera(await mainView.getCamera());
    // _camera is now the main view's camera; _updateParameters reads it from
    // the field rather than off the view, because View::getCamera has no
    // "is there a camera" guard on the native side and returns a dangling
    // pointer once the camera has been detached.

    await _createSceneRenderTarget(width, height);
    await _createScatterRenderTargets(width, height);

    // The main view must be redirected before it is submitted, otherwise the
    // blur passes would sample the previous frame.
    await mainView.setRenderTarget(_sceneRenderTarget);

    // Each blur pass writes into its own half of the ping-pong pair.
    await horizontalBlurView.setRenderTarget(_scatterARenderTarget);
    await verticalBlurView.setRenderTarget(_scatterBRenderTarget);

    final rm = _app.renderManager;
    await rm.detach(mainView, swapChain: swapChain);
    await rm.attach(maskView, swapChain, renderOrder: 0);
    await rm.attach(mainView, swapChain, renderOrder: 1);
    await rm.attach(horizontalBlurView, swapChain, renderOrder: 2);
    await rm.attach(verticalBlurView, swapChain, renderOrder: 3);
    await rm.attach(compositeView, swapChain, renderOrder: 4);

    await compositeView.setRenderTarget(_outputRenderTarget);

    await _updateParameters();

    _logger.info("Subsurface scattering enabled (${width}x$height)");
  }

  /// Undoes [enable] and destroys every resource this manager owns.
  Future<void> disable() async {
    final rm = _app.renderManager;
    await rm.detach(maskView);
    await rm.detach(horizontalBlurView);
    await rm.detach(verticalBlurView);
    await rm.detach(compositeView);

    await horizontalBlurView.setRenderTarget(null);
    await verticalBlurView.setRenderTarget(null);
    await compositeView.setRenderTarget(null);

    await maskView.setCamera(null);

    if (_mainView != null) {
      await _mainView!.setRenderTarget(_originalMainViewRenderTarget as FFIRenderTarget?);
    }

    await _app.flush();

    await _destroySceneRenderTarget();
    await _destroyScatterRenderTargets();

    _mainView = null;
    _camera = null;
    _outputRenderTarget = null;
    _originalMainViewRenderTarget = null;

    _logger.info("Subsurface scattering disabled");
  }

  Future<void> destroy() async {
    await disable();

    await maskView.destroy();
    await horizontalBlurView.destroy();
    await verticalBlurView.destroy();
    await compositeView.destroy();
  }

  /// Points the mask pass at [camera], so it stays in register with the main
  /// view.
  ///
  /// Called by `FFIView.setCamera` whenever the main view's camera changes.
  Future<void> setCamera(Camera? camera) async {
    _camera = camera;
    await maskView.setCamera(camera);
    // depthRange and the orthographic flag are read off the camera.
    await _updateParameters();
  }

  /// Re-renders the internal targets for a new main view size.
  Future<void> setViewport(int width, int height) async {
    if (width <= 0 || height <= 0) return;

    await maskView.setViewport(width, height);
    final (scatterWidth, scatterHeight) = _scatterSize(width, height, parameters.blurResolutionScale);
    await horizontalBlurView.setViewport(scatterWidth, scatterHeight);
    await verticalBlurView.setViewport(scatterWidth, scatterHeight);
    await compositeView.setViewport(width, height);

    if (_sceneRenderTarget != null && (width != _sceneWidth || height != _sceneHeight)) {
      await _resizeSceneRenderTarget(width, height);
    }
    await _resizeScatterRenderTargets(width, height);

    await _updateParameters();
  }

  Future<void> setParameters(SubsurfaceScatteringParameters parameters) async {
    parameters.blurResolutionScale = math.min(math.max(parameters.blurResolutionScale, 1.0 / 8.0), 1.0);
    this.parameters = parameters;
    await _updateParameters();
  }

  Future<void> _createSceneRenderTarget(int width, int height) async {
    // SRGB8_A8, matching HighlightOverlayManager's main view target: post
    // processing writes linear colours, the GPU encodes them on write and
    // linearises them again on sample, so every pass in the chain works in
    // linear space and nothing gets gamma corrected twice.
    _sceneColorTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.SRGB8_A8,
            )
            as FFITexture;

    // SAMPLEABLE as well as a depth attachment: both blur passes and the
    // composite pass read this texture to weight their samples.
    _sceneDepthTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.DEPTH32F,
            )
            as FFITexture;

    _sceneRenderTarget =
        await _app.createRenderTarget(width, height, color: _sceneColorTexture, depth: _sceneDepthTexture)
            as FFIRenderTarget;

    _sceneWidth = width;
    _sceneHeight = height;
  }

  /// Size of the scatter buffers for a main view of [width] x [height].
  static (int, int) _scatterSize(int width, int height, double scale) {
    return (math.max(1, (width * scale).floor()), math.max(1, (height * scale).floor()));
  }

  Future<void> _createScatterRenderTargets(int width, int height) async {
    final (w, h) = _scatterSize(width, height, parameters.blurResolutionScale);

    _scatterATexture = await _createScatterTexture(w, h);
    _scatterBTexture = await _createScatterTexture(w, h);
    // The blur materials do not read or write depth, but Filament's skybox /
    // clear path wants a depth attachment on the render target, so give each
    // scatter target one anyway.
    _scatterADepthTexture = await _createScatterDepthTexture(w, h);
    _scatterBDepthTexture = await _createScatterDepthTexture(w, h);
    _scatterARenderTarget =
        await _app.createRenderTarget(w, h, color: _scatterATexture, depth: _scatterADepthTexture) as FFIRenderTarget;
    _scatterBRenderTarget =
        await _app.createRenderTarget(w, h, color: _scatterBTexture, depth: _scatterBDepthTexture) as FFIRenderTarget;

    await horizontalBlurView.setRenderTarget(_scatterARenderTarget);
    await verticalBlurView.setRenderTarget(_scatterBRenderTarget);

    _scatterWidth = w;
    _scatterHeight = h;
  }

  Future<FFITexture> _createScatterDepthTexture(int width, int height) async {
    return await _app.createTexture(
          width,
          height,
          flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT},
          textureFormat: TextureFormat.DEPTH32F,
        )
        as FFITexture;
  }

  Future<FFITexture> _createScatterTexture(int width, int height) async {
    // Same encoding as the scene colour target, so a scatter buffer written by
    // one pass reads back linear in the next.
    return await _app.createTexture(
          width,
          height,
          flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
          textureFormat: TextureFormat.SRGB8_A8,
        )
        as FFITexture;
  }

  Future<void> _resizeSceneRenderTarget(int width, int height) async {
    final oldColor = _sceneColorTexture;
    final oldDepth = _sceneDepthTexture;
    final oldRenderTarget = _sceneRenderTarget;

    await _createSceneRenderTarget(width, height);
    await _mainView!.setRenderTarget(_sceneRenderTarget);

    await _updateParameters();
    await _app.flush();

    await oldRenderTarget?.destroy();
    await oldColor?.dispose();
    await oldDepth?.dispose();
  }

  Future<void> _resizeScatterRenderTargets(int width, int height) async {
    final (w, h) = _scatterSize(width, height, parameters.blurResolutionScale);

    if (w == _scatterWidth && h == _scatterHeight && _scatterARenderTarget != null) {
      return;
    }

    final oldA = _scatterATexture;
    final oldB = _scatterBTexture;
    final oldADepth = _scatterADepthTexture;
    final oldBDepth = _scatterBDepthTexture;
    final oldART = _scatterARenderTarget;
    final oldBRT = _scatterBRenderTarget;

    await _createScatterRenderTargets(width, height);

    await _updateParameters();
    await _app.flush();

    await oldART?.destroy();
    await oldBRT?.destroy();
    await oldA?.dispose();
    await oldB?.dispose();
    await oldADepth?.dispose();
    await oldBDepth?.dispose();
  }

  Future<void> _destroySceneRenderTarget() async {
    await _sceneRenderTarget?.destroy();
    await _sceneColorTexture?.dispose();
    await _sceneDepthTexture?.dispose();
    _sceneRenderTarget = null;
    _sceneColorTexture = null;
    _sceneDepthTexture = null;
  }

  Future<void> _destroyScatterRenderTargets() async {
    await _scatterARenderTarget?.destroy();
    await _scatterBRenderTarget?.destroy();
    await _scatterATexture?.dispose();
    await _scatterBTexture?.dispose();
    await _scatterADepthTexture?.dispose();
    await _scatterBDepthTexture?.dispose();
    _scatterARenderTarget = null;
    _scatterBRenderTarget = null;
    _scatterATexture = null;
    _scatterBTexture = null;
    _scatterADepthTexture = null;
    _scatterBDepthTexture = null;
  }

  /// Pushes the current parameter set and texture bindings onto all four
  /// material instances.
  Future<void> _updateParameters() async {
    final maskTexture = maskView.maskTexture as FFITexture;
    final sceneColor = _sceneColorTexture;
    final sceneDepth = _sceneDepthTexture;
    final scatterA = _scatterATexture;
    final scatterB = _scatterBTexture;

    if (sceneColor == null || sceneDepth == null || scatterA == null || scatterB == null) {
      return;
    }

    var orthographic = false;
    List<double> depthRange = const [0.1, 100.0];
    // The camera is cached by [setCamera] rather than read back off the main
    // view: reading it back crashes once the main view has detached its camera
    // (the native View::getCamera has no null guard).
    final camera = _camera;
    if (camera != null) {
      final near = await camera.getNear();
      final far = await camera.getCullingFar();
      if (near > 0 && far > near) {
        depthRange = [near, far];
      }
      // Filament exposes no "is orthographic" query, so read it off the
      // projection matrix instead. A perspective projection stores -1 in the
      // w row's z column and 0 in its w column; an orthographic projection
      // stores the identity w row. This holds regardless of which NDC depth
      // convention the backend uses. Matrix4.storage is column-major, so the
      // w column is element [15].
      final projection = await camera.getProjectionMatrix();
      orthographic = projection.storage[15] != 0.0;
    }

    // `scatterRadius` is authored in full-resolution screen pixels. The
    // horizontal pass reads the full-resolution scene colour, so its texels
    // are already full-resolution pixels; the vertical pass reads the reduced-
    // resolution scatter buffer, where one texel covers more than one screen
    // pixel, so its radius has to be divided by the same factor the buffer was
    // divided by.
    final radius = [parameters.radiusRed, parameters.radiusGreen, parameters.radiusBlue];
    final reducedRadius = [
      parameters.radiusRed / parameters.blurResolutionScale,
      parameters.radiusGreen / parameters.blurResolutionScale,
      parameters.radiusBlue / parameters.blurResolutionScale,
    ];

    await horizontalBlurView.setParameters(
      colorTexture: sceneColor,
      depthTexture: sceneDepth,
      maskTexture: maskTexture,
      directionX: 1.0,
      directionY: 0.0,
      texelSizeX: 1.0 / _sceneWidth,
      texelSizeY: 1.0 / _sceneHeight,
      scatterRadius: radius,
      depthFalloff: parameters.depthFalloff,
      depthRange: depthRange,
      orthographic: orthographic,
      useDepth: parameters.depthAware,
      useMask: parameters.maskAware,
    );

    await verticalBlurView.setParameters(
      colorTexture: scatterA,
      depthTexture: sceneDepth,
      maskTexture: maskTexture,
      directionX: 0.0,
      directionY: 1.0,
      texelSizeX: 1.0 / _scatterWidth,
      texelSizeY: 1.0 / _scatterHeight,
      scatterRadius: reducedRadius,
      depthFalloff: parameters.depthFalloff,
      depthRange: depthRange,
      orthographic: orthographic,
      useDepth: parameters.depthAware,
      useMask: parameters.maskAware,
    );

    await compositeView.setParameters(
      sceneColorTexture: sceneColor,
      scatteredTexture: scatterB,
      maskTexture: maskTexture,
      intensity: parameters.intensity,
    );
  }
}
