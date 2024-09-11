import 'dart:async';
import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:vector_math/vector_math_64.dart';
import '../thermion_viewer.dart';

class Gizmo extends AbstractGizmo {
  final ThermionEntity x;
  final ThermionEntity y;
  final ThermionEntity z;
  final ThermionEntity center;

  final ThermionViewer _viewer;

  ThermionEntity? _activeAxis;
  ThermionEntity? _activeEntity;

  bool _visible = false;
  bool get isVisible => _visible;

  bool _isHovered = false;
  bool get isHovered => _isHovered;

  final Set<ThermionEntity> ignore;

  Stream<Aabb2> get boundingBox => _boundingBoxController.stream;
  final _boundingBoxController = StreamController<Aabb2>.broadcast();

  Gizmo(this.x, this.y, this.z, this.center, this._viewer,
      {this.ignore = const <ThermionEntity>{}}) {
    _viewer.gizmoPickResult.listen(_onGizmoPickResult);
    _viewer.pickResult.listen(_onPickResult);
  }

  final _stopwatch = Stopwatch();

  double _transX = 0.0;
  double _transY = 0.0;

  Future translate(double transX, double transY) async {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    _transX += transX;
    _transY += transY;

    if (_stopwatch.elapsedMilliseconds < 16) {
      return;
    }

    final axis = Vector3(_activeAxis == x ? 1.0 : 0.0,
        _activeAxis == y ? 1.0 : 0.0, _activeAxis == z ? 1.0 : 0.0);

    await _viewer.queueRelativePositionUpdateWorldAxis(
        _activeEntity!,
        _transX * _viewer.pixelRatio,
        -_transY *
            _viewer
                .pixelRatio, // flip the sign because "up" in NDC Y axis is positive, but negative in Flutter
        axis.x,
        axis.y,
        axis.z);
    _transX = 0;
    _transY = 0;
    _stopwatch.reset();
  }

  void reset() {
    _activeAxis = null;
  }

  void _onPickResult(FilamentPickResult result) async {
    await attach(result.entity);
  }

  void _onGizmoPickResult(FilamentPickResult result) async {
    if (result.entity == x || result.entity == y || result.entity == z) {
      _activeAxis = result.entity;
      _isHovered = true;
    } else if (result.entity == 0) {
      _activeAxis = null;
      _isHovered = false;
    } else {
      throw Exception("Unexpected gizmo pick result");
    }
  }

  Future attach(ThermionEntity entity) async {
    print("Attaching");
    _activeAxis = null;
    if (entity == _activeEntity) {
      return;
    }
    if (entity == center) {
      _activeEntity = null;
      return;
    }
    _visible = true;

    if (_activeEntity != null) {
      await _viewer.removeStencilHighlight(_activeEntity!);
    }
    _activeEntity = entity;
    await _viewer.setGizmoVisibility(true);
    await _viewer.setParent(center, entity, preserveScaling: true);
    _boundingBoxController.sink.add(await _viewer.getViewportBoundingBox(x));

  }

  Future detach() async {
    await _viewer.setGizmoVisibility(false);
  }

  @override
  void checkHover(double x, double y) {
    _viewer.pickGizmo(x.toInt(), y.toInt());
  }
}
