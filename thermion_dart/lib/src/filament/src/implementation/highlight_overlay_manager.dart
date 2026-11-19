import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/edge_detection_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/silhouette_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

abstract class HighlightOverlayManager {
  View get silhouetteView;
  View get overlayView;
  Future setSwapChain(SwapChain swapChain);
  Future setCamera(Camera? camera);
  Future setViewport(int width, int height);
  Future setRenderTarget(View mainView, RenderTarget? renderTarget);
  Future destroy();
  Set<ThermionEntity> get highlightedEntities;

  Future<void> addHighlight({
    required ThermionEntity target,
    double outlineWidth = 3.0,
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
  });
  Future<void> removeHighlight(ThermionEntity target);

  static Future<HighlightOverlayManager> create(FFIFilamentApp app, int width, int height) {
    return FFIHighlightOverlayManager.create(app, width: width, height: height);
  }
}

/// Manages the highlight overlay system for screen-space outline rendering.
///
/// This class encapsulates the two-pass rendering approach:
/// 1. Silhouette pass: Render highlighted entities to a texture as white silhouettes
/// 2. Edge detection pass: Fullscreen shader samples silhouette, draws outline where edges are detected
///
/// ## Creation Flow (macOS composite mode)
///
/// When [create] is called:
/// 1. **SilhouetteView** is created, which OWNS:
///    - `_colorTexture` (RGBA8, sampleable) - the silhouette render output
///    - `_renderTarget` backed by `_colorTexture` (color-only)
///    - `_silhouetteMaterial` and a single shared `_silhouetteMaterialInstance`
///      registered as a view material override
///
/// 2. **EdgeDetectionView** is created, which OWNS:
///    - `_edgeMaterial` and `_edgeMaterialInstance`
///    - Fullscreen quad geometry (`_quadVB`, `_quadIB`, `_fullscreenQuadEntity`)
///    - `_edgeScene`, `_camera`, `_skybox`
///    - Texture samplers (`_edgeSampler`, `_mainSceneSampler`)
///
///    EdgeDetectionView receives a REFERENCE to `silhouetteView.colorTexture`
///    (does NOT own it). This texture is bound to `_edgeMaterialInstance`.
///
/// 3. When [setRenderTarget] is called (macOS/iOS composite mode):
///    - This manager creates `_mainViewColorTexture` (SRGB8_A8, sampleable)
///    - Main view is redirected to render to this internal texture
///    - EdgeDetectionView receives a REFERENCE to `_mainViewColorTexture`
///      and binds it to `_edgeMaterialInstance` as the 'mainScene' parameter
///
/// **Texture ownership summary:**
/// - `_silhouetteTexture` in EdgeDetectionView → OWNED by SilhouetteView
/// - `_mainSceneTexture` in EdgeDetectionView → OWNED by this manager
/// - `_edgeMaterialInstance` holds REFERENCES to both textures
///
/// ## Destruction Flow
///
/// When [destroy] is called, resources must be destroyed in the correct order
/// to avoid crashes from textures being destroyed while still bound to
/// material instances:
///
/// 1. **clearHighlights()** - removes all silhouette entities:
///    - For each highlighted entity: remove from scene, destroy entity,
///      destroy its silhouette material instance
///
/// 2. **overlayView.destroy()** - destroys EdgeDetectionView:
///    - Removes fullscreen quad from scene, destroys quad entity
///    - Destroys `_edgeMaterialInstance` (releases texture bindings)
///    - Destroys geometry buffers, skybox, scene, camera, material
///
/// 3. **flush()** - synchronizes with render thread:
///    - CRITICAL: Must happen AFTER material instance destruction but BEFORE
///      texture destruction to ensure render thread has processed the
///      material instance cleanup
///
/// 4. **silhouetteView.destroy()** - destroys SilhouetteView:
///    - Destroys `_colorTexture` (the silhouette texture)
///    - Now safe because EdgeDetectionView's material instance is gone
///    - Restores main view's original render target
///    - Destroys `_mainViewColorTexture` (the main scene texture)
///
class FFIHighlightOverlayManager extends HighlightOverlayManager {
  final _logger = Logger('HighlightOverlayManager');

  // Views (always non-null after construction via create())
  final SilhouetteView silhouetteView;
  final EdgeDetectionView overlayView;

  final _highlightedEntities = <ThermionEntity>{};

  @override
  Set<ThermionEntity> get highlightedEntities => Set.unmodifiable(_highlightedEntities);

  // State
  View? _mainView;
  SwapChain? _swapChain;

  // The platform-owned target the main view's final image should reach.
  // Updated on every setRenderTarget call (including resize replacements and
  // null detaches) so teardown never restores a target a previous resize
  // already destroyed.
  RenderTarget? _presentationRenderTarget;

  // Whether the main view is currently redirected to the internal composite
  // target. Cleared when a null presentation target routes it back to direct
  // output, so later resize/teardown calls do not re-bind or restore stale
  // targets.
  bool _mainViewRedirected = false;

  // Internal render target for main view (composite mode only)
  Texture? _mainViewColorTexture;
  Texture? _mainViewDepthTexture;
  RenderTarget? _mainViewRenderTarget;

  /// Set the presentation target for composite mode (macOS/iOS).
  ///
  /// The main view is redirected to an internal render target so the edge
  /// detection view can composite the main scene with edge outlines into
  /// [presentationRenderTarget].
  ///
  /// Passing null detaches the presentation target: the edge detection view
  /// stops rendering into it (so the caller can destroy it safely) and the
  /// main view falls back to rendering directly into its swapchain. The
  /// internal composite target is kept for a later non-null call.
  ///
  /// Can be called multiple times (e.g. on resize) — will update the
  /// render target that EdgeDetectionView outputs to.
  Future<void> setRenderTarget(View mainView, RenderTarget? presentationRenderTarget) async {
    _mainView = mainView;

    _presentationRenderTarget = presentationRenderTarget;

    if (_mainViewRenderTarget == null && presentationRenderTarget != null) {
      // First composite target — set up the internal RT for the main view
      final vp = await mainView.getViewport();
      final width = vp.width > 0 ? vp.width : 1;
      final height = vp.height > 0 ? vp.height : 1;

      await _createMainViewRenderTarget(width, height);
      await overlayView.setMainSceneTexture(_mainViewColorTexture!);
      _logger.info("Main-view composite target initialized");
    }

    await overlayView.setRenderTarget(presentationRenderTarget);
    // Without a presentation target both views draw to the swapchain; the
    // edge pass must overlay edges with alpha instead of compositing an
    // opaque quad (sampling the stale internal texture) over the main view.
    await overlayView.setOverlayOnly(presentationRenderTarget == null);

    if (presentationRenderTarget == null) {
      // No frame may sample or present through the target the caller is
      // about to destroy: route the main view back to direct output.
      if (_mainViewRedirected) {
        await mainView.setRenderTarget(null);
        _mainViewRedirected = false;
      }
    } else if (!_mainViewRedirected) {
      await mainView.setRenderTarget(_mainViewRenderTarget);
      _mainViewRedirected = true;
      _logger.info("Main view redirected to internal render target (composite mode)");
    }
    _logger.info("Presentation render target updated");
  }

  /// Set the swapchain for overlay mode (web/Android).
  ///
  /// The main view renders directly to the swapchain. The edge detection
  /// view outputs only edges with alpha transparency and is registered
  /// with the swapchain to render on top.
  Future<void> setSwapChain(SwapChain swapChain) async {
    if (_swapChain != null) {
      // Already registered — nothing to do
      return;
    }

    await overlayView.setRenderTarget(null);
    _swapChain = swapChain;
    await overlayView.setOverlayOnly(true);
    _logger.info("EdgeDetectionView registered with swapchain (overlay-only mode)");
  }

  final FFIFilamentApp _app;

  FFIHighlightOverlayManager._({required this.silhouetteView, required this.overlayView, required FFIFilamentApp app})
    : _app = app;

  /// Creates and initializes a new [HighlightOverlayManager].
  static Future<HighlightOverlayManager> create(FFIFilamentApp app, {required int width, required int height}) async {
    // Use 1x1 minimum to avoid 0-dimension textures during early init
    final actualWidth = width > 0 ? width : 1;
    final actualHeight = height > 0 ? height : 1;

    // Create silhouette view (first pass) — opaque so the black skybox clears background pixels
    final silhouetteView = await SilhouetteView.create(app, width: actualWidth, height: actualHeight);
    await silhouetteView.setBlendMode(BlendMode.opaque);

    // Create edge detection view (second pass)
    final edgeDetectionView = await EdgeDetectionView.create(
      app,
      width: actualWidth,
      height: actualHeight,
      silhouetteTexture: silhouetteView.colorTexture,
    );

    // Wire up texture resize callback so EdgeDetectionView gets notified
    // when SilhouetteView resizes its render target
    silhouetteView.onTextureResized = (newTexture) async {
      await edgeDetectionView.updateSilhouetteTexture(newTexture);
    };

    await edgeDetectionView.setBlendMode(BlendMode.transparent);

    final manager = FFIHighlightOverlayManager._(
      silhouetteView: silhouetteView,
      overlayView: edgeDetectionView,
      app: app,
    );

    manager._logger.info("Highlight overlay manager initialized");

    return manager;
  }

  /// Set the camera for the silhouette view.
  Future<void> setCamera(Camera? camera) async {
    await silhouetteView.setCamera(camera);
  }

  /// Update viewport size for both views.
  Future<void> setViewport(int width, int height) async {
    await silhouetteView.setViewport(width, height);
    await overlayView.setViewport(width, height);

    // Resize internal render target if in composite mode
    if (_mainView != null && _mainViewRenderTarget != null) {
      await _resizeMainViewRenderTarget(width, height);
    }
  }

  Future<void> _createMainViewRenderTarget(int width, int height) async {
    // Create color texture with sampleable flag.
    // Use SRGBA8 format so that:
    // 1. Main view post-processing outputs linear colors → GPU applies sRGB encoding
    // 2. EdgeDetectionView samples → GPU linearizes the values automatically
    // This prevents double gamma correction that causes brightness shift.
    _mainViewColorTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT, TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
              textureFormat: TextureFormat.SRGB8_A8,
            )
            as FFITexture;

    // Create depth texture
    _mainViewDepthTexture =
        await _app.createTexture(
              width,
              height,
              flags: {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT},
              textureFormat: TextureFormat.DEPTH32F,
            )
            as FFITexture;

    // Create render target
    _mainViewRenderTarget =
        await _app.createRenderTarget(width, height, color: _mainViewColorTexture, depth: _mainViewDepthTexture)
            as FFIRenderTarget;
  }

  Future<void> _resizeMainViewRenderTarget(int width, int height) async {
    if (_mainViewRenderTarget == null) return;

    // Store old resources (keep alive until new ones are bound to prevent race conditions)
    final oldColorTexture = _mainViewColorTexture;
    final oldDepthTexture = _mainViewDepthTexture;
    final oldRenderTarget = _mainViewRenderTarget;

    // Create new resources FIRST
    await _createMainViewRenderTarget(width, height);

    // Update all references before destroying old resources. Only re-bind
    // the main view if it is currently redirected; after a null presentation
    // target it renders directly and must stay there.
    if (_mainView != null && _mainViewRedirected) {
      await _mainView!.setRenderTarget(_mainViewRenderTarget);
    }
    await overlayView.setMainSceneTexture(_mainViewColorTexture!);

    // Flush render thread to ensure new textures are bound before destroying old ones
    // This prevents "Invalid texture still bound to MaterialInstance" errors
    await _app.flush();

    // NOW safe to destroy old resources
    await oldRenderTarget?.destroy();
    await oldColorTexture?.destroy();
    await oldDepthTexture?.destroy();

    _logger.info("Main view render target resized to ${width}x${height}");
  }

  Future<void> _destroyMainViewRenderTarget() async {
    if (_mainViewRenderTarget != null) {
      await _mainViewRenderTarget!.destroy();
      _mainViewRenderTarget = null;
    }
    if (_mainViewColorTexture != null) {
      await _mainViewColorTexture!.destroy();
      _mainViewColorTexture = null;
    }
    if (_mainViewDepthTexture != null) {
      await _mainViewDepthTexture!.destroy();
      _mainViewDepthTexture = null;
    }
  }

  /// Add a highlight for an entity.
  Future<void> addHighlight({
    required ThermionEntity target,
    double outlineWidth = 3.0,
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
  }) async {
    // ALWAYS update outline params (even if already highlighted)
    await overlayView.setOutlineParams(width: outlineWidth, r: r, g: g, b: b);

    // Only add silhouette if not already tracked
    if (_highlightedEntities.contains(target)) {
      return;
    }

    if (!_app.renderableManager.hasComponent(target)) {
      _logger.warning('Entity $target is not renderable');
      return;
    }

    // Add silhouette to first pass
    await silhouetteView.addHighlight(target: target);

    _highlightedEntities.add(target);
  }

  /// Remove highlight from an entity.
  Future<void> removeHighlight(ThermionEntity target) async {
    if (!_highlightedEntities.contains(target)) {
      return;
    }

    await silhouetteView.removeHighlight(target);
    _highlightedEntities.remove(target);
  }

  /// Remove all highlights.
  Future<void> clearHighlights() async {
    final entities = _highlightedEntities.toList();
    for (final entity in entities) {
      await removeHighlight(entity);
    }
  }

  /// Clean up all resources.
  ///
  /// See class documentation for the required destruction order.
  Future<void> destroy() async {
    _logger.info("Destroying highlight overlay");
    await clearHighlights();
    _logger.info("Cleared highlights");

    // Destroy EdgeDetectionView FIRST (destroys material instance, releases texture bindings)
    await overlayView.destroy();

    _logger.info("Destroyed overlay view");

    // NOW safe to destroy SilhouetteView (which destroys the silhouette texture)
    await silhouetteView.destroy();

    // Tear down render targets and restore direct presentation. Only restore
    // if the main view is still redirected: after a null presentation target
    // it already renders directly. Restore the CURRENT presentation target —
    // a resize may have replaced (and destroyed) the one captured earlier.
    if (_mainView != null && _mainViewRedirected) {
      await _mainView!.setRenderTarget(_presentationRenderTarget);
      _mainViewRedirected = false;
    }

    if (_swapChain != null) {
      _swapChain = null;
      _logger.info("EdgeDetectionView unregistered from swapchain");
    }

    // Clean up internal render target
    await _destroyMainViewRenderTarget();

    _mainView = null;
    _presentationRenderTarget = null; // Don't destroy - the platform layer owns this

    _logger.info("Highlight overlay torn down");

    _logger.info("Highlight overlay manager destroyed");
  }
}
