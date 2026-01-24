import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
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

    await overlayView.destroy();
    await silhouetteView.destroy();

    _logger.info("Highlight overlay manager destroyed");
  }
}
