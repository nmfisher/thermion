import 'package:reactphysics3d_dart/reactphysics3d_dart.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Basic rigid-body physics scene: boxes and spheres dropped into a walled arena.
///
/// The simulation runs with `reactphysics3d_dart` and renders with
/// `thermion_dart`. Call [step] each frame for live animation (e.g. in the
/// browser or headless video capture), [advanceFixed] for deterministic
/// still-frame capture, and [reset] to drop the bodies again.
class PhysicsScene {
  static const double fixedTimeStep = 1.0 / 60.0;

  static const _wallSpecs = [
    (0.0, -8.0, 0.0),
    (0.0, 8.0, 0.0),
    (-8.0, 0.0, 1.5707963267948966),
    (8.0, 0.0, 1.5707963267948966),
  ];

  static const _boxSpecs = [
    (-2.5, 6.0, 0.0),
    (0.0, 9.0, 1.5),
    (2.5, 6.0, -1.0),
    (0.5, 13.0, 0.5),
  ];

  static const _sphereSpecs = [
    (-1.5, 11.0, 1.0),
    (1.8, 8.0, 1.2),
    (0.0, 15.0, -0.5),
  ];

  final List<ThermionAsset> _boxMeshes;
  final List<ThermionAsset> _sphereMeshes;

  late ReactPhysics3D _physics;
  late PhysicsWorld _world;
  final List<(ThermionAsset, RigidBody)> _bodies = [];
  double _accumulator = 0.0;
  bool _disposed = false;

  PhysicsScene._(this._boxMeshes, this._sphereMeshes) {
    _buildPhysicsWorld();
  }

  /// Creates the lit arena, meshes, and initial ReactPhysics3D world on [viewer].
  static Future<PhysicsScene> create(
    ThermionViewer viewer, {
    required String assetsDir,
  }) async {
    final camera = await viewer.getActiveCamera();
    final viewport = await viewer.view.getViewport();
    await camera.setLensProjection(
      near: 0.1,
      far: 100.0,
      aspect: viewport.width / viewport.height,
      focalLength: 28.0,
    );
    await camera.lookAt(Vector3(0, 7, 16), focus: Vector3(0, 1.5, 0));

    await viewer.addDirectLight(
      DirectLight.sun(intensity: 50000, direction: Vector3(0, -1, -1)),
    );
    await viewer.loadSkybox('$assetsDir/default_env_skybox.ktx');
    await viewer.loadIbl('$assetsDir/default_env_ibl.ktx');

    // Destroy ubershader material instances on viewer dispose so
    // FilamentApp.destroy() can finish tearing down the engine cleanly.
    Future<MaterialInstance> coloredMaterial(
      double r,
      double g,
      double b,
    ) async {
      final material =
          await FilamentApp.instance!.createUbershaderMaterialInstance();
      viewer.onDispose(material.destroy);
      await material.setParameterInt('baseColorIndex', -1);
      await material.setParameterFloat4('baseColorFactor', r, g, b, 1.0);
      return material;
    }

    // Rendered ground: a flat cube matching the collider (cube spans [-1,1]).
    final groundMesh = await viewer.createGeometry(
      GeometryUtils.cube(uvs: false),
      materialInstances: [await coloredMaterial(0.35, 0.35, 0.35)],
    );
    await groundMesh.setTransform(
      Matrix4.compose(
        Vector3(0, -0.5, 0),
        Quaternion.identity(),
        Vector3(20, 0.5, 20),
      ),
    );

    // Low walls around the drop zone so rolling spheres stay in frame.
    for (final (x, z, yaw) in _wallSpecs) {
      final wallMesh = await viewer.createGeometry(
        GeometryUtils.cube(uvs: false),
        materialInstances: [await coloredMaterial(0.55, 0.55, 0.6)],
      );
      await wallMesh.setTransform(
        Matrix4.compose(
          Vector3(x, 1.0, z),
          Quaternion.euler(yaw, 0, 0),
          Vector3(8, 1, 0.5),
        ),
      );
    }

    final boxMeshes = <ThermionAsset>[];
    for (var i = 0; i < _boxSpecs.length; i++) {
      boxMeshes.add(
        await viewer.createGeometry(
          GeometryUtils.cube(uvs: false),
          materialInstances: [await coloredMaterial(0.9, 0.4, 0.1)],
        ),
      );
    }

    final sphereMeshes = <ThermionAsset>[];
    for (var i = 0; i < _sphereSpecs.length; i++) {
      sphereMeshes.add(
        await viewer.createGeometry(
          GeometryUtils.sphere(uvs: false),
          materialInstances: [await coloredMaterial(0.2, 0.45, 0.9)],
        ),
      );
    }

    final scene = PhysicsScene._(boxMeshes, sphereMeshes);
    viewer.onDispose(() async => scene.dispose());
    await scene.syncTransforms();
    return scene;
  }

  void _buildPhysicsWorld() {
    _physics = createReactPhysics3D();
    _world = _physics.createWorld();
    _world.setGravity(Vector3(0, -9.81, 0));
    _bodies.clear();

    // Static ground: a box collider whose top surface sits at y = 0.
    final groundShape = _physics.createBoxShape(Vector3(20, 0.5, 20));
    final groundBody = _world.createRigidBody(
      transform: (
        position: Vector3(0, -0.5, 0),
        orientation: Quaternion.identity(),
      ),
    );
    groundBody.type = BodyType.STATIC;
    groundBody.mass = 0;
    final groundCollider = groundBody.addCollider(groundShape);
    groundCollider.material.setFrictionCoefficient(0.8);
    groundCollider.material.setBounciness(0.0);

    // Static boundary walls.
    final wallShape = _physics.createBoxShape(Vector3(8, 1, 0.5));
    for (final (x, z, yaw) in _wallSpecs) {
      final wallBody = _world.createRigidBody(
        transform: (
          position: Vector3(x, 1.0, z),
          orientation: Quaternion.euler(yaw, 0, 0),
        ),
      );
      wallBody.type = BodyType.STATIC;
      wallBody.mass = 0;
      final wallCollider = wallBody.addCollider(wallShape);
      wallCollider.material.setFrictionCoefficient(0.8);
      wallCollider.material.setBounciness(0.0);
    }

    // Dynamic boxes (GeometryUtils.cube spans [-1, 1] -> half-extent 1).
    final boxShape = _physics.createBoxShape(Vector3.all(1));
    for (var i = 0; i < _boxSpecs.length; i++) {
      final (x, y, z) = _boxSpecs[i];
      final body = _world.createRigidBody(
        transform: (
          position: Vector3(x, y, z),
          orientation: Quaternion.identity(),
        ),
      );
      final collider = body.addCollider(boxShape);
      collider.material.setBounciness(0.15);
      collider.material.setFrictionCoefficient(0.9);
      _bodies.add((_boxMeshes[i], body));
    }

    // Dynamic spheres (GeometryUtils.sphere has radius 1).
    final sphereShape = _physics.createSphereShape(1.0);
    for (var i = 0; i < _sphereSpecs.length; i++) {
      final (x, y, z) = _sphereSpecs[i];
      final body = _world.createRigidBody(
        transform: (
          position: Vector3(x, y, z),
          orientation: Quaternion.identity(),
        ),
      );
      final collider = body.addCollider(sphereShape);
      collider.material.setBounciness(0.3);
      collider.material.setFrictionCoefficient(0.7);
      _bodies.add((_sphereMeshes[i], body));
    }
  }

  /// Advances the simulation by [dt] seconds using fixed 60 Hz substeps and
  /// copies the updated rigid-body transforms to the Thermion renderables.
  Future<void> step(double dt) async {
    if (_disposed) return;
    _accumulator += dt.clamp(0.0, 0.1);
    var stepped = false;
    while (_accumulator >= fixedTimeStep) {
      _world.update(fixedTimeStep);
      _accumulator -= fixedTimeStep;
      stepped = true;
    }
    if (stepped) {
      await syncTransforms();
    }
  }

  /// Steps the simulation exactly [steps] times at [fixedTimeStep] (60 Hz)
  /// and syncs transforms to the renderables.
  Future<void> advanceFixed(int steps) async {
    if (_disposed) return;
    for (var i = 0; i < steps; i++) {
      _world.update(fixedTimeStep);
    }
    await syncTransforms();
  }

  /// Copies every dynamic rigid body's transform to its Thermion entity.
  Future<void> syncTransforms() async {
    if (_disposed) return;
    for (final (mesh, body) in _bodies) {
      final transform = body.transform;
      await mesh.setTransform(
        Matrix4.compose(
          transform.position,
          transform.orientation,
          Vector3.all(1),
        ),
      );
    }
  }

  /// Resets the physics world so all boxes and spheres drop from their initial
  /// positions again.
  Future<void> reset() async {
    if (_disposed) return;
    _physics.dispose();
    _accumulator = 0.0;
    _buildPhysicsWorld();
    await syncTransforms();
  }

  /// Releases the native/WASM ReactPhysics3D world.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bodies.clear();
    _physics.dispose();
  }
}
