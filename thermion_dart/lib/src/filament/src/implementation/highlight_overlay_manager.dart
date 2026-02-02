import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/edge_detection_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/silhouette_view.dart';
import 'package:thermion_dart/thermion_dart.dart';

abstract class HighlightOverlayManager {
  View get silhouetteView;
  View get overlayView;
  Future setSwapChain(SwapChain swapChain);
  Future setCamera(Camera camera);
  Future setViewport(int width, int height);
  Future setRenderTarget(View mainView, RenderTarget renderTarget);
  Future destroy();
  bool isInternalRenderTarget(RenderTarget renderTarget);

  Future<void> addHighlight({
    required ThermionEntity target,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
    required int indexCount,
    double outlineWidth = 3.0,
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
  });
  Future<void> removeHighlight(ThermionEntity target);

  static Future<HighlightOverlayManager> create(int width, int height) {
    return FFIHighlightOverlayManager.create(width: width, height: height);
  }
}

/// Manages the highlight overlay system for screen-space outline rendering.
///
/// This class encapsulates the two-pass rendering approach:
/// 1. Silhouette pass: Render highlighted entities to a texture as white silhouettes
/// 2. Edge detection pass: Fullscreen shader samples silhouette, draws outline where edges are detected
class FFIHighlightOverlayManager extends HighlightOverlayManager {
  final _logger = Logger('HighlightOverlayManager');

  // Views (always non-null after construction via create())
  final SilhouetteView silhouetteView;
  final EdgeDetectionView overlayView;

  final _highlightedEntities = <ThermionEntity>{};

  // State
  View? _mainView;
  RenderTarget? _originalMainViewRenderTarget;
  SwapChain? _swapChain;
  RenderTarget? _flutterRenderTarget;

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
  Future<void> setRenderTarget(
    View mainView,
    RenderTarget flutterRenderTarget,
  ) async {
    _mainView = mainView;

    if (_flutterRenderTarget == null) {
      // First time — set up the internal RT and redirect main view
      _originalMainViewRenderTarget = await mainView.getRenderTarget();

      final vp = await mainView.getViewport();
      final width = vp.width > 0 ? vp.width : 1;
      final height = vp.height > 0 ? vp.height : 1;

      await _createMainViewRenderTarget(width, height);
      await mainView.setRenderTarget(_mainViewRenderTarget);
      await overlayView.setMainSceneTexture(_mainViewColorTexture!);
      _logger.info(
          "Main view redirected to internal render target (composite mode)");
    }

    _flutterRenderTarget = flutterRenderTarget;
    await overlayView.setRenderTarget(flutterRenderTarget);
    _logger.info("EdgeDetectionView configured for render target output");
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
    _logger.info(
        "EdgeDetectionView registered with swapchain (overlay-only mode)");
  }

  /// Check if the given render target is the internal one used for main view
  /// (as opposed to a Flutter-provided render target).
  /// Used by FFIView.setRenderTarget() to determine if it should intercept.
  bool isInternalRenderTarget(RenderTarget rt) {
    return rt == _mainViewRenderTarget;
  }

  FFIHighlightOverlayManager._({
    required this.silhouetteView,
    required this.overlayView,
  });

  /// Creates and initializes a new [HighlightOverlayManager].
  static Future<HighlightOverlayManager> create({
    required int width,
    required int height,
  }) async {
    // Use 1x1 minimum to avoid 0-dimension textures during early init
    final actualWidth = width > 0 ? width : 1;
    final actualHeight = height > 0 ? height : 1;

    // Create silhouette view (first pass)
    final silhouetteView = await SilhouetteView.create(
      width: actualWidth,
      height: actualHeight,
    );
    await silhouetteView.setBlendMode(BlendMode.transparent);

    // Create edge detection view (second pass)
    final edgeDetectionView = await EdgeDetectionView.create(
      width: actualWidth,
      height: actualHeight,
      silhouetteTexture: silhouetteView.colorTexture,
    );

    // Post-processing is disabled on EdgeDetectionView (see edge_detection_view.dart)
    // to avoid double tone-mapping in composite mode.
    await edgeDetectionView.setAntiAliasing(false, true, false);

    // Wire up texture resize callback so EdgeDetectionView gets notified
    // when SilhouetteView resizes its render target
    silhouetteView.onTextureResized = (newTexture) async {
      await edgeDetectionView.updateSilhouetteTexture(newTexture);
    };

    await edgeDetectionView.setBlendMode(BlendMode.transparent);

    final manager = FFIHighlightOverlayManager._(
      silhouetteView: silhouetteView,
      overlayView: edgeDetectionView,
    );

    manager._logger.info("Highlight overlay manager initialized");

    return manager;
  }

  /// Set the camera for the silhouette view.
  Future<void> setCamera(Camera camera) async {
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

  /// Tear down render targets and restore original state.
  Future<void> _teardown() async {
    // Restore main view's original render target (only if it was redirected)
    if (_mainView != null && _mainViewRenderTarget != null) {
      await _mainView!
          .setRenderTarget(_originalMainViewRenderTarget as FFIRenderTarget?);
    }

    // If EdgeDetectionView was registered with swapchain, unregister it
    if (_swapChain != null) {
      await FilamentApp.instance!
          .setRenderOrder(_swapChain!, overlayView as FFIView, renderOrder: -1);
      _swapChain = null;
      _logger.info("EdgeDetectionView unregistered from swapchain");
    }

    // Clean up internal render target
    await _destroyMainViewRenderTarget();

    _mainView = null;
    _originalMainViewRenderTarget = null;
    _flutterRenderTarget = null; // Don't destroy - Flutter layer owns this

    _logger.info("Highlight overlay torn down");
  }

  Future<void> _createMainViewRenderTarget(int width, int height) async {
    // Create color texture with sampleable flag
    _mainViewColorTexture = await FilamentApp.instance!.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
      },
      textureFormat: TextureFormat.RGBA8,
    ) as FFITexture;

    // Create depth texture
    _mainViewDepthTexture = await FilamentApp.instance!.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
      },
      textureFormat: TextureFormat.DEPTH32F,
    ) as FFITexture;

    // Create render target
    _mainViewRenderTarget = await FilamentApp.instance!.createRenderTarget(
      width,
      height,
      color: _mainViewColorTexture,
      depth: _mainViewDepthTexture,
    ) as FFIRenderTarget;
  }

  Future<void> _resizeMainViewRenderTarget(int width, int height) async {
    if (_mainViewRenderTarget == null) return;

    // Store old resources (keep alive until new ones are bound to prevent race conditions)
    final oldColorTexture = _mainViewColorTexture;
    final oldDepthTexture = _mainViewDepthTexture;
    final oldRenderTarget = _mainViewRenderTarget;

    // Create new resources FIRST
    await _createMainViewRenderTarget(width, height);

    // Update all references before destroying old resources
    if (_mainView != null) {
      await _mainView!.setRenderTarget(_mainViewRenderTarget);
    }
    await overlayView.setMainSceneTexture(_mainViewColorTexture!);

    // Flush render thread to ensure new textures are bound before destroying old ones
    // This prevents "Invalid texture still bound to MaterialInstance" errors
    await FilamentApp.instance!.flush();

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

  /// Add a highlight for an entity with the specified geometry.
  Future<void> addHighlight({
    required ThermionEntity target,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
    required int indexCount,
    double outlineWidth = 3.0,
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
  }) async {
    // ALWAYS update outline params (even if already highlighted)
    await overlayView.setOutlineParams(
      width: outlineWidth,
      r: r,
      g: g,
      b: b,
    );

    // Only add silhouette if not already tracked
    if (_highlightedEntities.contains(target)) {
      return;
    }

    // Add silhouette to first pass
    await silhouetteView.addHighlight(
      target: target,
      vertexBuffer: vertexBuffer,
      indexBuffer: indexBuffer,
      indexCount: indexCount,
    );

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
  Future<void> destroy() async {
    await clearHighlights();

    // Tear down render targets and restore original state
    await _teardown();

    await overlayView.destroy();
    await silhouetteView.destroy();

    _logger.info("Highlight overlay manager destroyed");
  }
}
