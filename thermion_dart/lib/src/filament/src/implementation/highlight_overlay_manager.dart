import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/edge_detection_view.dart';
import 'package:thermion_dart/src/filament/src/implementation/silhouette_view.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Manages the highlight overlay system for screen-space outline rendering.
///
/// This class encapsulates the two-pass rendering approach:
/// 1. Silhouette pass: Render highlighted entities to a texture as white silhouettes
/// 2. Edge detection pass: Fullscreen shader samples silhouette, draws outline where edges are detected
class HighlightOverlayManager {
  final _logger = Logger('HighlightOverlayManager');
  final FFIFilamentApp _app;

  // Views (always non-null after construction via create())
  final SilhouetteView silhouetteView;
  final EdgeDetectionView overlayView;

  final _highlightedEntities = <ThermionEntity>{};

  // Initialization state
  bool _initialized = false;
  FFIView? _mainView;
  RenderTarget? _originalMainViewRenderTarget;
  FFISwapChain? _swapChain;  // Stored for Android cleanup
  FFIRenderTarget? _flutterRenderTarget;  // The Flutter-bound RT (for EdgeDetectionView on macOS)

  // Internal render target for main view
  FFITexture? _mainViewColorTexture;
  FFITexture? _mainViewDepthTexture;
  FFIRenderTarget? _mainViewRenderTarget;

  /// Whether the manager has been initialized with render targets
  bool get initialized => _initialized;

  /// Get the Flutter render target that EdgeDetectionView renders to.
  /// Used by FFIView.getRenderTarget() in composite mode so Flutter
  /// destroys the correct RT during resize.
  RenderTarget? getFlutterRenderTarget() {
    return _flutterRenderTarget;
  }

  /// Update the Flutter render target (called during resize on macOS).
  /// This updates EdgeDetectionView to render to the new Flutter RT.
  Future<void> updateFlutterRenderTarget(FFIRenderTarget newRenderTarget) async {
    if (!_initialized) return;

    _flutterRenderTarget = newRenderTarget;
    await overlayView.setRenderTarget(newRenderTarget);
    _logger.info("Updated Flutter render target for EdgeDetectionView");
  }

  /// Check if the given render target is the internal one used for main view
  /// (as opposed to a Flutter-provided render target).
  /// Used by FFIView.setRenderTarget() to determine if it should intercept.
  bool isInternalRenderTarget(RenderTarget rt) {
    return rt == _mainViewRenderTarget;
  }

  HighlightOverlayManager._(
    this._app, {
    required this.silhouetteView,
    required this.overlayView,
  });

  /// Creates and initializes a new [HighlightOverlayManager].
  static Future<HighlightOverlayManager> create(
    FFIFilamentApp app, {
    required int width,
    required int height,
  }) async {
    // Use 1x1 minimum to avoid 0-dimension textures during early init
    final actualWidth = width > 0 ? width : 1;
    final actualHeight = height > 0 ? height : 1;

    // Create silhouette view (first pass)
    final silhouetteView = await SilhouetteView.create(
      app,
      width: actualWidth,
      height: actualHeight,
    );
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

    final manager = HighlightOverlayManager._(
      app,
      silhouetteView: silhouetteView,
      overlayView: edgeDetectionView,
    );

    manager._logger.info("Highlight overlay manager initialized");
    return manager;
  }

  /// Whether there are any active highlights.
  bool get hasHighlights => _highlightedEntities.isNotEmpty;

  /// Set the camera for the silhouette view.
  Future<void> setCamera(Camera camera) async {
    await silhouetteView.setCamera(camera);
  }

  /// Update viewport size for both views.
  Future<void> setViewport(int width, int height) async {
    await silhouetteView.setViewport(width, height);
    await overlayView.setViewport(width, height);

    // Resize internal render target if initialized
    if (_initialized && _mainView != null) {
      await _resizeMainViewRenderTarget(width, height);
    }
  }

  /// Initialize the highlight overlay with render targets.
  ///
  /// The main view renders to an internal texture which is then sampled by the
  /// edge detection view. The edge detection view composites the main scene with
  /// edge outlines and outputs to the Flutter-bound texture.
  ///
  /// [mainView] - The main view to redirect to internal render target
  /// [flutterRenderTarget] - The Flutter-bound render target for final output (macOS)
  /// [swapChain] - The swapchain to register EdgeDetectionView with (Android)
  ///
  /// On macOS, EdgeDetectionView renders to [flutterRenderTarget].
  /// On Android, EdgeDetectionView is registered with [swapChain] to render to the native surface.
  Future<void> initialize(
    FFIView mainView,
    RenderTarget? flutterRenderTarget,
    SwapChain? swapChain,
  ) async {
    if (_initialized) {
      _logger.warning("Already initialized");
      return;
    }

    if (flutterRenderTarget == null && swapChain == null) {
      _logger.warning("Requires either a render target or swapchain");
      return;
    }

    _initialized = true;
    _mainView = mainView;
    _originalMainViewRenderTarget = await mainView.getRenderTarget();

    final vp = await mainView.getViewport();
    final width = vp.width > 0 ? vp.width : 1;
    final height = vp.height > 0 ? vp.height : 1;

    // Create internal sampleable render target for main view
    await _createMainViewRenderTarget(width, height);

    // Redirect main view to internal render target
    await mainView.setRenderTarget(_mainViewRenderTarget);

    // Configure EdgeDetectionView output
    if (flutterRenderTarget != null) {
      // macOS path: render to Flutter's render target
      _flutterRenderTarget = flutterRenderTarget as FFIRenderTarget;
      await overlayView.setRenderTarget(_flutterRenderTarget);
      _logger.info("EdgeDetectionView configured for render target output");
    } else if (swapChain != null) {
      // Android path: register EdgeDetectionView with swapchain
      await overlayView.setRenderTarget(null);  // Clear any RT
      _swapChain = swapChain as FFISwapChain;
      await _app.register(_swapChain!, overlayView as FFIView);
      _logger.info("EdgeDetectionView registered with swapchain");
    }

    // Pass main scene texture to edge detection view
    await overlayView.setMainSceneTexture(_mainViewColorTexture!);

    _logger.info("Highlight overlay initialized");
  }

  /// Tear down render targets and restore original state.
  Future<void> _teardown() async {
    if (!_initialized) {
      return;
    }

    _initialized = false;

    // Restore main view's original render target (may be null for Android/swapchain case)
    if (_mainView != null) {
      await _mainView!.setRenderTarget(_originalMainViewRenderTarget as FFIRenderTarget?);
    }

    // If EdgeDetectionView was registered with swapchain (Android), unregister it
    if (_swapChain != null) {
      await _app.unregister(_swapChain!, overlayView as FFIView);
      _swapChain = null;
      _logger.info("EdgeDetectionView unregistered from swapchain");
    }

    // Clean up internal render target
    await _destroyMainViewRenderTarget();

    _mainView = null;
    _originalMainViewRenderTarget = null;
    _flutterRenderTarget = null;  // Don't destroy - Flutter layer owns this

    _logger.info("Highlight overlay torn down");
  }

  Future<void> _createMainViewRenderTarget(int width, int height) async {
    // Create color texture with sampleable flag
    _mainViewColorTexture = await _app.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
      },
      textureFormat: TextureFormat.RGBA8,
    ) as FFITexture;

    // Create depth texture
    _mainViewDepthTexture = await _app.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
      },
      textureFormat: TextureFormat.DEPTH32F,
    ) as FFITexture;

    // Create render target
    _mainViewRenderTarget = await _app.createRenderTarget(
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

    // Update outline params on edge detection view
    await overlayView.setOutlineParams(
      width: outlineWidth,
      r: r,
      g: g,
      b: b,
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
