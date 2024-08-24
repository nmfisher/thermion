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
  bool get isActive => _activeAxis != null;

  final Set<ThermionEntity> ignore;

  Stream<Aabb2> get boundingBox => _boundingBoxController.stream;
  final _boundingBoxController = StreamController<Aabb2>.broadcast();


  Gizmo(this.x, this.y, this.z, this.center, this._viewer,
      {this.ignore = const <ThermionEntity>{}}) {
    _viewer.pickResult.listen(_onPickResult);

  }

  Future _reveal() async {
    await _viewer.reveal(x, null);
    await _viewer.reveal(y, null);
    await _viewer.reveal(z, null);
    await _viewer.reveal(center, null);
  }

  final _stopwatch = Stopwatch();

  var _translation = Vector3.zero();

  void translate(double transX, double transY) async {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }

    _translation = Vector3(_activeAxis == x ? 1.0 : 0.0,
        _activeAxis == y ? 1.0 : 0.0, _activeAxis == z ? 1.0 : 0.0);

    await _viewer.queueRelativePositionUpdateWorldAxis(
        _activeEntity!,
        transX * _viewer.pixelRatio,
        -transY * _viewer.pixelRatio,
        _translation.x,
        _translation.y,
        _translation.z);
    _stopwatch.reset();
    _translation = Vector3.zero();
  }

  void reset() {
    _activeAxis = null;
  }

  void _onPickResult(FilamentPickResult result) async {
    // print(
    //     "Pick result ${result}, x is ${x}, y is $y, z is $z, ignore is $ignore");
    // if (ignore.contains(result)) {
    //   print("Ignore/detach");
    //   detach();
    //   return;
    // }
    if (result.entity == x || result.entity == y || result.entity == z) {
      _activeAxis = result.entity;
      print("Set active axis to $_activeAxis");
    } else {
      attach(result.entity);
      print("Attaching to ${result.entity}");
    }
  }

  void attach(ThermionEntity entity) async {
    _activeAxis = null;
    _activeEntity = entity;
    await _reveal();

    await _viewer.setParent(center, entity);

    _boundingBoxController.sink.add(await _viewer.getBoundingBox(x));
  }

  void detach() async {
    await _viewer.setParent(center, 0);
    await _viewer.hide(x, null);
    await _viewer.hide(y, null);
    await _viewer.hide(z, null);
    await _viewer.hide(center, null);
  }

  @override
  void checkHover(double x, double y) {
    _viewer.pick(x.toInt(), y.toInt());
  }
}
