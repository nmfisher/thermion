import 'package:reactphysics3d_dart/reactphysics3d_dart.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Basic physics: boxes and spheres dropped onto a ground plane.
///
/// The simulation runs with reactphysics3d_dart, the rendering with
/// thermion_dart. The world is stepped a fixed number of times with a fixed
/// time step (no wall-clock dependency), then each body's transform is copied
/// to its Thermion entity. That way the headless CLI runner can capture a
/// single frame of the settled pile.
///
/// NOTE (web path blocked): this example is native/headless only and is NOT
/// wired into the web gallery. reactphysics3d_dart pins ffigen_js 0.0.5-pre,
/// which conflicts with thermion_dart's ffigen_js ^0.0.14-pre -- the packages
/// only resolve together through a dependency_overrides entry (see the
/// pubspecs under examples/dart). Its WASM runtime path is unverified, so do
/// not add it to [galleryScenes] until that pin is relaxed upstream.
Future<void> setupPhysicsBasics(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(0, 7, 16), focus: Vector3(0, 1.5, 0));

  await viewer.addDirectLight(
    DirectLight.sun(intensity: 50000, direction: Vector3(0, -1, -1)),
  );
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  // Simple coloured PBR materials so the bodies stand out against the ground.
  // Each instance is destroyed on viewer dispose: leaving ubershader material
  // instances alive blocks FilamentApp.destroy() (the render thread never
  // finishes tearing the engine down). Disposal runs after the viewer has
  // destroyed its geometry assets, so the instances are unreferenced by then.
  Future<MaterialInstance> coloredMaterial(double r, double g, double b) async {
    final material = await FilamentApp.instance!.createUbershaderMaterialInstance();
    await material.setParameterInt('baseColorIndex', -1);
    await material.setParameterFloat4('baseColorFactor', r, g, b, 1.0);
    viewer.onDispose(material.destroy);
    return material;
  }

  // Physics world.
  final physics = createReactPhysics3D();
  final world = physics.createWorld();
  world.setGravity(Vector3(0, -9.81, 0));

  // Static ground: a box collider whose top surface sits at y=0.
  final groundShape = physics.createBoxShape(Vector3(20, 0.5, 20));
  final groundBody = physics.createRigidBody(
    world,
    transform: (
      position: Vector3(0, -0.5, 0),
      orientation: Quaternion.identity(),
    ),
    type: BodyType.STATIC,
    mass: 0,
  );
  final groundCollider = groundBody.addCollider(groundShape);
  groundCollider.material.setFrictionCoefficient(0.8);
  groundCollider.material.setBounciness(0.0);

  // Rendered ground: a flat cube matching the collider (cube spans [-1,1]).
  final groundMesh = await viewer.createGeometry(
    GeometryUtils.cube(uvs: false),
    materialInstances: [await coloredMaterial(0.35, 0.35, 0.35)],
  );
  await groundMesh.setTransform(
    Matrix4.compose(Vector3(0, -0.5, 0), Quaternion.identity(), Vector3(20, 0.5, 20)),
  );

  // Low walls around the drop zone so the rolling spheres stay in frame.
  // Each wall is a static box collider plus a matching thin cube mesh.
  final wallShape = physics.createBoxShape(Vector3(8, 1, 0.5));
  const wallSpecs = [
    (0.0, -8.0, 0.0),
    (0.0, 8.0, 0.0),
    (-8.0, 0.0, 1.5707963267948966),
    (8.0, 0.0, 1.5707963267948966),
  ];
  for (final (x, z, yaw) in wallSpecs) {
    final wallBody = physics.createRigidBody(
      world,
      transform: (
        position: Vector3(x, 1.0, z),
        orientation: Quaternion.euler(yaw, 0, 0),
      ),
      type: BodyType.STATIC,
      mass: 0,
    );
    final wallCollider = wallBody.addCollider(wallShape);
    wallCollider.material.setFrictionCoefficient(0.8);
    wallCollider.material.setBounciness(0.0);
    final wallMesh = await viewer.createGeometry(
      GeometryUtils.cube(uvs: false),
      materialInstances: [await coloredMaterial(0.55, 0.55, 0.6)],
    );
    await wallMesh.setTransform(
      Matrix4.compose(Vector3(x, 1.0, z), Quaternion.euler(yaw, 0, 0), Vector3(8, 1, 0.5)),
    );
  }

  final bodies = <(ThermionAsset, RigidBody)>[];

  // Falling boxes. GeometryUtils.cube() spans [-1,1], so the physics box has
  // half-extent 1 and the render scale stays 1.
  final boxShape = physics.createBoxShape(Vector3.all(1));
  const boxSpecs = [
    (-2.5, 6.0, 0.0),
    (0.0, 9.0, 1.5),
    (2.5, 6.0, -1.0),
    (0.5, 13.0, 0.5),
  ];
  for (final (x, y, z) in boxSpecs) {
    final body = physics.createRigidBody(
      world,
      transform: (
        position: Vector3(x, y, z),
        orientation: Quaternion.identity(),
      ),
    );
    final collider = body.addCollider(boxShape);
    collider.material.setBounciness(0.15);
    collider.material.setFrictionCoefficient(0.9);
    final mesh = await viewer.createGeometry(
      GeometryUtils.cube(uvs: false),
      materialInstances: [await coloredMaterial(0.9, 0.4, 0.1)],
    );
    bodies.add((mesh, body));
  }

  // Falling spheres. GeometryUtils.sphere() has radius 1.
  final sphereShape = physics.createSphereShape(1.0);
  const sphereSpecs = [
    (-1.5, 11.0, 1.0),
    (1.8, 8.0, 1.2),
    (0.0, 15.0, -0.5),
  ];
  for (final (x, y, z) in sphereSpecs) {
    final body = physics.createRigidBody(
      world,
      transform: (
        position: Vector3(x, y, z),
        orientation: Quaternion.identity(),
      ),
    );
    final collider = body.addCollider(sphereShape);
    collider.material.setBounciness(0.3);
    collider.material.setFrictionCoefficient(0.7);
    final mesh = await viewer.createGeometry(
      GeometryUtils.sphere(uvs: false),
      materialInstances: [await coloredMaterial(0.2, 0.45, 0.9)],
    );
    bodies.add((mesh, body));
  }

  // Step the simulation long enough for everything to settle (5 seconds at
  // 60 Hz). Fixed step count keeps the captured frame deterministic.
  const timeStep = 1 / 60;
  const steps = 300;
  for (var i = 0; i < steps; i++) {
    world.update(timeStep);
  }

  // Copy the final physics transforms to the render entities.
  for (final (mesh, body) in bodies) {
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
