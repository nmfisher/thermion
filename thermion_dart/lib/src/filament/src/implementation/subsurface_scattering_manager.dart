import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Diagnostic buffers produced by the actual opaque color pass.
enum SubsurfaceScatteringDebugOutput { composite, diffuse, coverage, depth }

/// Normalized Burley diffusion with post-scatter texturing.
/// Distances are the exponential length d in millimeters, not Gaussian sigma
/// or Blender UI radius. The radial profile is proportional to
/// (exp(-r/d) + exp(-r/(3d))) / (d*r), truncated at 16d.
/// These defaults are a small synthetic profile, not a measured skin preset.
class SubsurfaceScatteringParameters {
  final double diffusionDistanceRedMm;
  final double diffusionDistanceGreenMm;
  final double diffusionDistanceBlueMm;
  final double metersPerUnit;
  final double intensity;
  final SubsurfaceScatteringDebugOutput debugOutput;

  const SubsurfaceScatteringParameters({
    this.diffusionDistanceRedMm = 0.6,
    this.diffusionDistanceGreenMm = 0.3,
    this.diffusionDistanceBlueMm = 0.15,
    this.metersPerUnit = 1.0,
    this.intensity = 1.0,
    this.debugOutput = SubsurfaceScatteringDebugOutput.composite,
  });
}

/// Selects opaque lit primitives for Filament's internal diffuse diffusion pass.
/// No extra public views, render targets, or copied geometry are created.
/// Selected primitives receive a clone of their own material instance; edit the
/// currently bound instance while selected. Removing selection restores the
/// original instance. A primitive can be selected by only one manager at a time.
class SubsurfaceScatteringManager {
  final FFIFilamentApp _app;
  final View _view;
  final Map<(ThermionEntity, int), int> _selected = {};
  static int _nextGroup = 1;
  SubsurfaceScatteringParameters _parameters = const SubsurfaceScatteringParameters();
  bool _destroyed = false;

  SubsurfaceScatteringManager._(this._app, this._view);

  SubsurfaceScatteringParameters get parameters => _parameters;
  Set<ThermionEntity> get skinEntities => _selected.keys.map((key) => key.$1).toSet();

  static Future<SubsurfaceScatteringManager> create(FFIFilamentApp app, View view) async {
    final manager = SubsurfaceScatteringManager._(app, view);
    await manager.setParameters(manager.parameters);
    return manager;
  }

  Future<void> setParameters(SubsurfaceScatteringParameters parameters) async {
    if (_destroyed) throw StateError('SSS manager has been destroyed');
    for (final value in [
      parameters.diffusionDistanceRedMm,
      parameters.diffusionDistanceGreenMm,
      parameters.diffusionDistanceBlueMm,
      parameters.metersPerUnit,
    ]) {
      if (!value.isFinite || value <= 0)
        throw ArgumentError('Profile distances and scene units must be finite and positive');
    }
    if (!parameters.intensity.isFinite || parameters.intensity < 0 || parameters.intensity > 1) {
      throw ArgumentError.value(parameters.intensity, 'intensity', 'Must be between 0 and 1');
    }
    final scale = 0.001 / parameters.metersPerUnit;
    final ok = await withBoolCallback(
      (cb) => View_configureSssRenderThread(
        _app.engine,
        _view.getNativeHandle(),
        true,
        parameters.diffusionDistanceRedMm * scale,
        parameters.diffusionDistanceGreenMm * scale,
        parameters.diffusionDistanceBlueMm * scale,
        parameters.intensity,
        parameters.debugOutput.index,
        cb,
      ),
    );
    if (!ok) {
      throw UnsupportedError(
        'SSS requires the matching diffuse-SSS Filament build, with opaque scene composition, MSAA, fog and SSR disabled, and one SSS view per engine',
      );
    }
    _parameters = parameters;
  }

  /// Select one primitive. Sharing a transportGroup allows intended adjacent
  /// primitives to exchange light; different groups never exchange samples.
  Future<void> addPrimitive(ThermionEntity entity, int primitiveIndex, {int? transportGroup}) async {
    if (_destroyed) throw StateError('SSS manager has been destroyed');
    final key = (entity, primitiveIndex);
    if (_selected.containsKey(key)) return;
    final group = transportGroup ?? _nextGroup++;
    if (group < 1 || group > 0xffffff) throw ArgumentError.value(group, 'transportGroup');
    final ok = await withBoolCallback(
      (cb) => View_setSssPrimitiveRenderThread(
        _app.engine,
        _view.getNativeHandle(),
        entity,
        primitiveIndex,
        true,
        group,
        cb,
      ),
    );
    if (!ok)
      throw UnsupportedError(
        'SSS selection requires an available opaque standard-lit primitive compiled with the matching SSS compiler',
      );
    _selected[key] = group;
  }

  /// Convenience for an asset made entirely of eligible opaque lit primitives.
  /// Use addPrimitive for mixed skin/eyes/clothing assets.
  Future<void> addSkin(ThermionAsset asset) async {
    final before = _selected.keys.toSet();
    final group = _nextGroup++;
    try {
      for (final entity in [asset.entity, ...await asset.getChildEntities()]) {
        if (!_app.renderableManager.hasComponent(entity)) continue;
        final count = _app.renderableManager.getPrimitiveCount(entity);
        for (var primitive = 0; primitive < count; primitive++) {
          await addPrimitive(entity, primitive, transportGroup: group);
        }
      }
    } catch (_) {
      for (final key in _selected.keys.toSet().difference(before)) {
        await removePrimitive(key.$1, key.$2);
      }
      rethrow;
    }
  }

  Future<void> removePrimitive(ThermionEntity entity, int primitiveIndex) async {
    if (!_selected.containsKey((entity, primitiveIndex))) return;
    await withBoolCallback(
      (cb) =>
          View_setSssPrimitiveRenderThread(_app.engine, _view.getNativeHandle(), entity, primitiveIndex, false, 0, cb),
    );
    _selected.remove((entity, primitiveIndex));
  }

  Future<void> removeSkin(ThermionAsset asset) async {
    final entities = {asset.entity, ...await asset.getChildEntities()};
    for (final key in _selected.keys.toList()) {
      if (entities.contains(key.$1)) await removePrimitive(key.$1, key.$2);
    }
  }

  Future<void> destroy() async {
    if (_destroyed) return;
    await withBoolCallback(
      (cb) => View_configureSssRenderThread(_app.engine, _view.getNativeHandle(), false, 1, 1, 1, 0, 0, cb),
    );
    for (final key in _selected.keys.toList()) {
      await removePrimitive(key.$1, key.$2);
    }
    _destroyed = true;
  }
}
