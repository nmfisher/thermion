import 'package:logging/logging.dart';
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
/// 2. Edge detection pass: Fullscreen shader samples silhouette and alpha-blends
///    outlines directly on top of the main view's presentation target (or swapchain)
///
/// ## Creation Flow
///
/// When [create] is called:
/// 1. **SilhouetteView** is created, which OWNS:
///    - `_colorTexture` (RGBA8, sampleable) - the silhouette render output
///    - `_renderTarget` backed by `_colorTexture` (color-only)
///    - `_silhouetteMaterial` and a single shared `_silhouetteMaterialInstance`
///      registered as a view material override
///
/// 2. **EdgeDetectionView** is created with [BlendMode.transparent], which OWNS:
///    - `_edgeMaterial` and `_edgeMaterialInstance`
///    - Fullscreen quad geometry (`_quadVB`, `_quadIB`, `_fullscreenQuadEntity`)
///    - `_edgeScene`, `_camera`, `_skybox`
///    - Texture sampler (`_edgeSampler`)
///
///    EdgeDetectionView receives a REFERENCE to `silhouetteView.colorTexture`
///    (does NOT own it). This texture is bound to `_edgeMaterialInstance`.
///
/// 3. Both the main view and EdgeDetectionView render into the same presentation
///    [RenderTarget] (or swapchain when null); because EdgeDetectionView uses
///    [BlendMode.transparent] and shares the exact same [RenderTarget], Filament
///    preserves the main view's color pixels and blends outlines on top.
///
/// **Texture ownership summary:**
/// - `_silhouetteTexture` in EdgeDetectionView → OWNED by SilhouetteView
/// - `_edgeMaterialInstance` holds a REFERENCE to `_silhouetteTexture`
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
///    - Detaches its render target (releasing any reference to presentation RT)
///    - Removes fullscreen quad from scene, destroys quad entity
///    - Destroys `_edgeMaterialInstance` (releases texture bindings)
///    - Destroys geometry buffers, skybox, scene, camera, material
///
/// 3. **silhouetteView.destroy()** - destroys SilhouetteView:
///    - Destroys `_colorTexture` (the silhouette texture)
///    - Now safe because EdgeDetectionView's material instance is gone
///
class FFIHighlightOverlayManager extends HighlightOverlayManager {
  final _logger = Logger('HighlightOverlayManager');

  final FFIFilamentApp _app;

  // Passes (always non-null after construction via create())
  final SilhouetteView _silhouettePass;
  final EdgeDetectionView _edgeDetectionPass;

  @override
  View get silhouetteView => _silhouettePass.view;

  @override
  View get overlayView => _edgeDetectionPass.view;

  final _highlightedEntities = <ThermionEntity>{};

  @override
  Set<ThermionEntity> get highlightedEntities => Set.unmodifiable(_highlightedEntities);

  // State
  SwapChain? _swapChain;

  /// Bind [presentationRenderTarget] to both [mainView] and [overlayView]
  /// (or detach both back to the swapchain when null).
  ///
  /// Because [overlayView] renders after [mainView] with
  /// [BlendMode.transparent] targeting the exact same [RenderTarget], Filament
  /// preserves [mainView]'s rendered color contents across uncovered pixels and
  /// blends edge outlines directly on top without an intermediate copy pass.
  @override
  Future<void> setRenderTarget(View mainView, RenderTarget? presentationRenderTarget) async {
    await mainView.setRenderTarget(presentationRenderTarget);
    await _edgeDetectionPass.setRenderTarget(presentationRenderTarget);
    _logger.info("Presentation render target updated");
  }

  /// Set the swapchain for overlay mode (web/Android).
  ///
  /// Both the main view and edge detection view render directly to the
  /// swapchain; the edge detection view outputs edges with premultiplied alpha
  /// transparency on top.
  @override
  Future<void> setSwapChain(SwapChain swapChain) async {
    if (_swapChain != null) {
      // Already registered — nothing to do
      return;
    }

    await _edgeDetectionPass.setRenderTarget(null);
    _swapChain = swapChain;
    _logger.info("EdgeDetectionView registered with swapchain (overlay-only mode)");
  }

  FFIHighlightOverlayManager._({
    required SilhouetteView silhouettePass,
    required EdgeDetectionView edgeDetectionPass,
    required FFIFilamentApp app,
  }) : _silhouettePass = silhouettePass,
       _edgeDetectionPass = edgeDetectionPass,
       _app = app;

  /// Creates and initializes a new [HighlightOverlayManager].
  static Future<HighlightOverlayManager> create(FFIFilamentApp app, {required int width, required int height}) async {
    // Use 1x1 minimum to avoid 0-dimension textures during early init
    final actualWidth = width > 0 ? width : 1;
    final actualHeight = height > 0 ? height : 1;

    // Create silhouette pass (first pass) — opaque so the black skybox clears background pixels
    final silhouettePass = await SilhouetteView.create(app, width: actualWidth, height: actualHeight);
    await silhouettePass.view.setBlendMode(BlendMode.opaque);

    // Create edge detection pass (second pass)
    final edgeDetectionPass = await EdgeDetectionView.create(
      app,
      width: actualWidth,
      height: actualHeight,
      silhouetteTexture: silhouettePass.colorTexture,
    );

    // Wire up texture resize callback so EdgeDetectionView gets notified
    // when SilhouetteView resizes its render target
    silhouettePass.onTextureResized = (newTexture) async {
      await edgeDetectionPass.updateSilhouetteTexture(newTexture);
    };

    await edgeDetectionPass.view.setBlendMode(BlendMode.transparent);

    final manager = FFIHighlightOverlayManager._(
      silhouettePass: silhouettePass,
      edgeDetectionPass: edgeDetectionPass,
      app: app,
    );

    manager._logger.info("Highlight overlay manager initialized");

    return manager;
  }

  /// Set the camera for the silhouette view.
  @override
  Future<void> setCamera(Camera? camera) async {
    await _silhouettePass.setCamera(camera);
  }

  /// Update viewport size for both views.
  @override
  Future<void> setViewport(int width, int height) async {
    await _silhouettePass.setViewport(width, height);
    await _edgeDetectionPass.setViewport(width, height);
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
    await _edgeDetectionPass.setOutlineParams(width: outlineWidth, r: r, g: g, b: b);

    // Only add silhouette if not already tracked
    if (_highlightedEntities.contains(target)) {
      return;
    }

    if (!_app.renderableManager.hasComponent(target)) {
      _logger.warning('Entity $target is not renderable');
      return;
    }

    // Add silhouette to first pass
    await _silhouettePass.addHighlight(target: target);

    _highlightedEntities.add(target);
  }

  /// Remove highlight from an entity.
  Future<void> removeHighlight(ThermionEntity target) async {
    if (!_highlightedEntities.contains(target)) {
      return;
    }

    await _silhouettePass.removeHighlight(target);
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
  @override
  Future<void> destroy() async {
    _logger.info("Destroying highlight overlay");
    await clearHighlights();
    _logger.info("Cleared highlights");

    // Destroy EdgeDetectionView FIRST (destroys material instance, releases texture bindings)
    await _edgeDetectionPass.destroy();

    _logger.info("Destroyed overlay view");

    // NOW safe to destroy SilhouetteView (which destroys the silhouette texture)
    await _silhouettePass.destroy();

    if (_swapChain != null) {
      _swapChain = null;
      _logger.info("EdgeDetectionView unregistered from swapchain");
    }

    _logger.info("Highlight overlay manager destroyed");
  }
}
