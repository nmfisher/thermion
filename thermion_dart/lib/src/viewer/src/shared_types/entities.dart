library;

import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

export 'geometry.dart';
export 'gltf.dart';

export 'light_options.dart';

// repre handle that can be safely passed back to the rendering layer to manipulate an Entity
typedef ThermionEntity = int;

abstract class ThermionAsset {
  ThermionEntity get entity;
  Future<List<ThermionEntity>> getChildEntities();

  ///
  /// Renders an outline around [entity] with the given color.
  ///
  Future setStencilHighlight(
      {double r = 1.0, double g = 0.0, double b = 0.0, int? entityIndex});

  ///
  /// Removes the outline around [entity]. Noop if there was no highlight.
  ///
  Future removeStencilHighlight();

  ///
  ///
  ///
  Future<ThermionAsset> getInstance(int index);

  ///
  /// Create a new instance of [entity].
  /// Instances are not automatically added to the scene; you must
  /// call [addToScene].
  ///
  Future<ThermionAsset> createInstance(
      {covariant List<MaterialInstance>? materialInstances = null});

  ///
  /// Returns the number of instances associated with this asset.
  ///
  Future<int> getInstanceCount();

  ///
  /// Returns all instances of associated with this asset.
  ///
  Future<List<ThermionAsset>> getInstances();

  ///
  /// Adds all entities (renderable, lights and cameras) under [asset] to the scene.
  ///
  Future addToScene();

  ///
  /// Removes all entities (renderable, lights and cameras) under [asset] from the scene.
  ///
  Future removeFromScene();
}

enum Axis {
  X(const [1.0, 0.0, 0.0]),
  Y(const [0.0, 1.0, 0.0]),
  Z(const [0.0, 0.0, 1.0]);

  const Axis(this.vector);

  final List<double> vector;

  Vector3 asVector() => Vector3(vector[0], vector[1], vector[2]);
}

enum GizmoPickResultType { AxisX, AxisY, AxisZ, Parent, None }

enum GizmoType { translation, rotation }

abstract class GizmoAsset extends ThermionAsset {
  Future pick(int x, int y,
      {Future Function(GizmoPickResultType axis, Vector3 coords)? handler});
  Future highlight(Axis axis);
  Future unhighlight();
  bool isNonPickable(ThermionEntity entity);
  bool isGizmoEntity(ThermionEntity entity);
}
