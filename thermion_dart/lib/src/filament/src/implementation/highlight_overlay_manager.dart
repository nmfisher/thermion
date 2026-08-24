import 'dart:async';

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

  /// Updates the outline appearance on the edge-detection material.
  ///
  /// Callers that add several highlights in a row (e.g. once per primitive of
  /// an entity) should set these once per user-facing operation rather than
  /// once per [addHighlight] call.
  Future<void> setOutlineParams({double? width, double? r, double? g, double? b});

  /// Whether the overlay passes are currently skipped.
  bool get suspended;

  Future<void> addHighlight({
    required ThermionEntity target,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
    required int indexCount,
    double outlineWidth = 3.0,
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? primitiveKey,
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
///    - `_depthTexture` (DEPTH32F)
///    - `_renderTarget` combining the above
///    - `_silhouetteMaterial` and per-entity material instances
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

  /// Whether the silhouette/edge passes are currently skipped.
  ///
  /// Rendering the two overlay views costs two extra full-screen passes per
  /// frame even when they draw nothing, so they are marked non-renderable
  /// whenever the highlight set is empty. The initial value matches the
  /// attached-and-renderable state the views get when the overlay is enabled;
  /// [_reconcilePresentationState] applies the desired state after every input
  /// change.
  bool _suspended = false;

  @override
  bool get suspended => _suspended;

  // State
  View? _mainView;
  SwapChain? _swapChain;
  RenderTarget? _presentationRenderTarget;

  Future<void> _reconcileChain = Future.value();

  // Internal render target for main view (composite mode only)
  Texture? _mainViewColorTexture;
  Texture? _mainViewDepthTexture;
  RenderTarget? _mainViewRenderTarget;

  /// Set the render target for composite mode (macOS/iOS).
  ///
  /// The main view is redirected to an internal render target so the edge
  /// detection view can composite the main scene with edge outlines into
  /// [flutterRenderTarget].
  ///
  /// Can be called multiple times (e.g. on resize) — will update the
  /// Flutter render target that EdgeDetectionView outputs to.
  Future<void> setRenderTarget(View mainView, RenderTarget? presentationRenderTarget) async {
    _mainView = mainView;

    if (_mainViewRenderTarget == null && presentationRenderTarget != null) {
      final vp = await mainView.getViewport();
      final width = vp.width > 0 ? vp.width : 1;
      final height = vp.height > 0 ? vp.height : 1;

      await _createMainViewRenderTarget(width, height);
      await overlayView.setMainSceneTexture(_mainViewColorTexture!);
      _logger.info("Main-view composite target initialized");
    }

    _presentationRenderTarget = presentationRenderTarget;
    await overlayView.setRenderTarget(presentationRenderTarget);
    _logger.info("Presentation render target updated");

    await _reconcilePresentationState();
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

    await _reconcilePresentationState();
  }

  /// Reconciles target routing and view renderability from current desired
  /// state.
  ///
  /// This is deliberately idempotent: viewport and presentation-target
  /// changes must re-apply routing even when the highlight set is unchanged.
  /// Reconciliations are serialized so overlapping lifecycle calls cannot
  /// publish older state after newer state.
  Future<void> _reconcilePresentationState() {
    final completer = Completer<void>();
    final previous = _reconcileChain;
    _reconcileChain = completer.future.then((_) {}, onError: (_) {});
    return previous.then((_) async {
      try {
        await _applyPresentationState();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
        rethrow;
      }
    });
  }

  Future<void> _applyPresentationState() async {
    final hasOutput = _mainView == null || _presentationRenderTarget != null;
    final shouldSuspend = _highlightedEntities.isEmpty || !hasOutput;
    final stateChanged = _suspended != shouldSuspend;
    final rm = _app.renderManager;

    if (shouldSuspend) {
      // Disable both overlay views in one state update before routing the main
      // view directly to its output. No frame can run edge detection against
      // a directly-rendered main view.
      await rm.setRenderables({silhouetteView: false, overlayView: false});
      if (_mainView != null) {
        await _mainView!.setRenderTarget(_presentationRenderTarget);
      }
    } else {
      // Route the main view to its sampleable target before enabling the
      // overlay views together.
      if (_mainView != null && _mainViewRenderTarget != null) {
        await _mainView!.setRenderTarget(_mainViewRenderTarget);
      }
      await rm.setRenderables({silhouetteView: true, overlayView: true});
    }

    _suspended = shouldSuspend;
    if (stateChanged) {
      _logger.info(
        shouldSuspend
            ? "Overlay passes suspended"
            : "Overlay passes resumed (${_highlightedEntities.length} highlights)",
      );
    }
  }

  final FFIFilamentApp _app;

  FFIHighlightOverlayManager._({required this.silhouetteView, required this.overlayView, required FFIFilamentApp app})
    : _app = app;

  /// Creates and initializes a new [HighlightOverlayManager].
  static Future<HighlightOverlayManager> create(FFIFilamentApp app, {required int width, required int height}) async {
    // Use 1x1 minimum to avoid 0-dimension textures during early init
    final actualWidth = width > 0 ? width : 1;
    final actualHeight = height > 0 ? height : 1;

    // Create silhouette view (first pass)
    final silhouetteView = await SilhouetteView.create(app, width: actualWidth, height: actualHeight);
    await silhouetteView.setBlendMode(BlendMode.transparent);

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

    // Update all references and re-apply the current route before destroying
    // resources that may still be bound by the active plan.
    await overlayView.setMainSceneTexture(_mainViewColorTexture!);
    await _reconcilePresentationState();

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

  /// Updates the outline appearance on the edge-detection material.
  @override
  Future<void> setOutlineParams({double? width, double? r, double? g, double? b}) async {
    await overlayView.setOutlineParams(width: width, r: r, g: g, b: b);
  }

  /// Add a highlight for an entity with the specified geometry.
  ///
  /// [primitiveKey] deduplicates silhouettes per primitive when this is
  /// called once per primitive of the same entity. Outline appearance is
  /// NOT set here — callers set it once per user-facing operation via
  /// [setOutlineParams] (per-primitive calls would re-upload the same
  /// material parameters N times).
  @override
  Future<void> addHighlight({
    required ThermionEntity target,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
    required int indexCount,
    double outlineWidth = 3.0,
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? primitiveKey,
  }) async {
    final created = await silhouetteView.addHighlight(
      target: target,
      vertexBuffer: vertexBuffer,
      indexBuffer: indexBuffer,
      indexCount: indexCount,
      primitiveKey: primitiveKey,
    );

    if (created) {
      _highlightedEntities.add(target);
      await _reconcilePresentationState();
    }
  }

  /// Remove highlight from an entity.
  @override
  Future<void> removeHighlight(ThermionEntity target) async {
    if (!_highlightedEntities.contains(target)) {
      return;
    }

    await silhouetteView.removeHighlight(target);
    _highlightedEntities.remove(target);
    await _reconcilePresentationState();
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

    // Release the internal main-view target before destroying it. The current
    // presentation target, not the first target seen during initialization,
    // is authoritative after resize/replacement.
    if (_mainView != null) {
      await _mainView!.setRenderTarget(_presentationRenderTarget);
    }

    if (_swapChain != null) {
      _swapChain = null;
      _logger.info("EdgeDetectionView unregistered from swapchain");
    }

    // Clean up internal render target
    await _destroyMainViewRenderTarget();

    _mainView = null;
    _presentationRenderTarget = null; // Don't destroy - Flutter layer owns this

    _logger.info("Highlight overlay torn down");

    _logger.info("Highlight overlay manager destroyed");
  }
}
